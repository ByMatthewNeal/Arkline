import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

Deno.serve(async (req) => {
  const ok = (body: Record<string, unknown>, status = 200) =>
    new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } })

  if (req.method !== "POST") {
    return ok({ error: "Method not allowed" })
  }

  let payload: { briefingKey?: string; summaryText?: string }
  try {
    payload = await req.json()
  } catch {
    return ok({ error: "Invalid request body" })
  }

  const { briefingKey, summaryText } = payload
  if (!briefingKey || !summaryText) {
    return ok({ error: "briefingKey and summaryText are required" })
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!
  const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  const supabase = createClient(supabaseUrl, supabaseKey)

  const bucket = "briefing-audio"
  const filePath = `${briefingKey}.mp3`

  // Check for cached audio
  try {
    const { data: existing } = await supabase.storage
      .from(bucket)
      .createSignedUrl(filePath, 3600)

    if (existing?.signedUrl) {
      console.log(`Returning cached audio for ${briefingKey}`)
      return ok({ audioUrl: existing.signedUrl })
    }
  } catch (err) {
    console.log(`No cached audio for ${briefingKey}:`, err instanceof Error ? err.message : String(err))
  }

  // Strip markdown for TTS
  const spokenText = stripMarkdown(summaryText)
  console.log(`Generating TTS for ${briefingKey} (${spokenText.length} chars)`)

  const openaiKey = Deno.env.get("OPENAI_API_KEY")
  if (!openaiKey) {
    console.error("OPENAI_API_KEY not set")
    return ok({ error: "TTS service unavailable" })
  }

  // Call OpenAI TTS
  try {
    const ttsResponse = await fetch("https://api.openai.com/v1/audio/speech", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${openaiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "tts-1",
        voice: "nova",
        input: spokenText,
        response_format: "mp3",
      }),
    })

    if (!ttsResponse.ok) {
      const errorText = await ttsResponse.text()
      console.error(`OpenAI TTS error: ${ttsResponse.status} ${errorText}`)
      return ok({ error: "Failed to generate audio" })
    }

    const audioBuffer = await ttsResponse.arrayBuffer()
    const audioBytes = new Uint8Array(audioBuffer)
    console.log(`TTS generated: ${audioBytes.length} bytes`)

    // Upload to Supabase Storage
    const { error: uploadError } = await supabase.storage
      .from(bucket)
      .upload(filePath, audioBytes, {
        contentType: "audio/mpeg",
        upsert: true,
      })

    if (uploadError) {
      console.error("Storage upload failed:", uploadError.message)
      return ok({ error: "Failed to store audio" })
    }

    // Generate signed URL
    const { data: signedData, error: signError } = await supabase.storage
      .from(bucket)
      .createSignedUrl(filePath, 3600)

    if (signError || !signedData?.signedUrl) {
      console.error("Failed to create signed URL:", signError?.message)
      return ok({ error: "Failed to generate audio URL" })
    }

    console.log(`Audio cached and signed URL generated for ${briefingKey}`)
    return ok({ audioUrl: signedData.signedUrl })
  } catch (err) {
    const errMsg = err instanceof Error ? err.message : String(err)
    console.error("TTS generation failed:", errMsg)
    return ok({ error: "TTS generation failed" })
  }
})

function stripMarkdown(text: string): string {
  let result = text

  // Remove ## Posture section entirely (shown as pill in UI)
  result = result.replace(/## Posture\n[^\n]*\n?/g, "")

  // Replace section headers with spoken labels
  result = result.replace(/## The Rundown/g, "The Rundown. ")
  result = result.replace(/## Technical/g, "Technical. ")
  result = result.replace(/## Flow/g, "Capital Flow. ")
  result = result.replace(/## Signals/g, "Signals. ")

  // Strip remaining markdown formatting
  result = result.replace(/##\s*/g, "")
  result = result.replace(/\*\*/g, "")
  result = result.replace(/\*/g, "")

  // Clean up extra whitespace
  result = result.replace(/\n{3,}/g, "\n\n")
  result = result.trim()

  return result
}
