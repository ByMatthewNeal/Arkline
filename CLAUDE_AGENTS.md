# ArkLine Multi-Agent Development Guide

This document defines boundaries, ownership, and coordination rules for parallel Claude Code agent development.

---

## Agent Overview

| Agent | Domain | Primary Focus |
|-------|--------|---------------|
| **Agent 1** | Portfolio & DCA | Investment tracking, holdings, DCA reminders |
| **Agent 2** | Market & AI | Market data, sentiment, AI chat, community |
| **Agent 3** | Core & Infrastructure | Models, networking, services, app lifecycle |
| **Agent 5** | Design & Branding | UI/UX, design system, visual polish, brand consistency |

---

## File Ownership Matrix

### Agent 1: Portfolio & DCA Features

**OWNS (can modify):**
```
/Features/Portfolio/
/Features/DCAReminder/
/Data/Services/API/APIPortfolioService.swift
/Data/Services/API/APIDCAService.swift
/Data/Services/Mock/MockPortfolioService.swift
/Data/Services/Mock/MockDCAService.swift
/Data/Services/Protocols/PortfolioServiceProtocol.swift
/Data/Services/Protocols/DCAServiceProtocol.swift
```

**READ-ONLY:**
```
/Core/Theme/*
/SharedComponents/*
/Domain/Models/*
```

---

### Agent 2: Market & AIChat Features

**OWNS (can modify):**
```
/Features/Market/
/Features/AIChat/
/Features/Community/
/Data/Services/API/APIMarketService.swift
/Data/Services/API/APINewsService.swift
/Data/Services/API/APISentimentService.swift
/Data/Services/Mock/MockMarketService.swift
/Data/Services/Mock/MockNewsService.swift
/Data/Services/Mock/MockSentimentService.swift
/Data/Services/Protocols/MarketServiceProtocol.swift
/Data/Services/Protocols/NewsServiceProtocol.swift
/Data/Services/Protocols/SentimentServiceProtocol.swift
```

**READ-ONLY:**
```
/Core/Theme/*
/SharedComponents/*
/Domain/Models/*
```

---

### Agent 3: Core, Data Layer & Infrastructure

**OWNS (can modify):**
```
/Core/Extensions/
/Core/Utilities/
/Data/Network/
/Data/Services/ServiceContainer.swift
/Domain/Models/
/Features/Home/ViewModels/
/Features/Settings/
/Features/Profile/
/Features/Onboarding/
/Features/Authentication/
/App/
```

**READ-ONLY (coordinate with Agent 5):**
```
/Core/Theme/
/SharedComponents/
```

**COORDINATION DUTIES:**
- Create new Models when requested by other agents
- Update ServiceContainer for new service registrations
- Request UI components from Agent 5
- Handle business logic, not visual styling

---

## Julia's Admin Panel Design Reference (For Agent 5)

This is the authoritative design reference from `/Users/matt/Downloads/arkline_admin-main/`.

### Color Palette (Tailwind CSS)

| Token | Tailwind Class | Hex | Usage |
|-------|---------------|-----|-------|
| **Primary** | `sky-600` | #0284C7 | Primary buttons, active states |
| **Primary Hover** | `sky-700` | #0369A1 | Button hover states |
| **Primary Focus** | `sky-500/50` | #0EA5E9 50% | Focus rings |
| **Background** | `gray-50` | #F9FAFB | Page backgrounds |
| **Surface** | `white` | #FFFFFF | Cards, modals |
| **Text Primary** | `slate-800` | #1E293B | Headings, important text |
| **Text Secondary** | `slate-600` | #475569 | Labels, body text |
| **Text Muted** | `slate-500` | #64748B | Placeholder, hints |
| **Border** | `slate-200` | #E2E8F0 | Card borders, dividers |
| **Success** | `green-600` | #16A34A | Success states |
| **Success Background** | `green-50` | #F0FDF4 | Success alerts |
| **Error** | `red-600` | #DC2626 | Error states, delete |
| **Error Background** | `red-50` | #FEF2F2 | Error alerts |

### Typography

| Element | Classes | Usage |
|---------|---------|-------|
| **Page Title** | `text-2xl font-semibold` | Login title |
| **Section Title** | `text-xl font-semibold` | Form headers |
| **Card Title** | `text-lg font-semibold` | Card headers |
| **Body** | `text-sm` | Default body text |
| **Label** | `text-sm font-medium` | Form labels |
| **Font Family** | Geist Sans | Primary font |

### Component Patterns

**Cards:**
```
bg-white shadow-sm border border-slate-200 rounded-lg p-4
```

**Primary Button:**
```
bg-sky-600 text-white font-semibold rounded-md p-2.5
hover:bg-sky-700 disabled:opacity-50 disabled:cursor-not-allowed
```

**Secondary Button:**
```
bg-slate-100 text-slate-700 rounded-md px-4 py-2
hover:bg-slate-200 text-sm
```

**Danger Button:**
```
bg-red-600 text-white rounded-md px-4 py-2
hover:bg-red-700 text-sm font-medium
```

**Input Fields:**
```
w-full border-slate-300 rounded-md p-2
focus:outline-none focus:ring-2 focus:ring-sky-500/50
```

**Error Input:**
```
border-red-500 focus:ring-red-500/50
```

**Modal Overlay:**
```
fixed inset-0 z-50 flex items-center justify-center bg-black/30
```

**Modal Content:**
```
bg-white rounded-lg shadow-lg p-6 w-full max-w-md
```

**Navigation (Active):**
```
text-sky-600 bg-sky-50 border-r-4 border-sky-600
```

**Navigation (Inactive):**
```
text-slate-600 hover:bg-slate-50
```

**Status Indicator (Active):**
```
w-2 h-2 rounded-full bg-green-500
```

**Status Indicator (Inactive):**
```
w-2 h-2 rounded-full bg-slate-400
```

### Spacing Patterns

| Context | Value |
|---------|-------|
| Card padding | `p-4`, `p-6`, `p-8` |
| Form field gap | `space-y-4`, `space-y-5` |
| Button padding | `px-4 py-2`, `p-2.5` |
| Grid gap | `gap-4`, `gap-5` |
| Section margin | `mb-4`, `mb-6` |

### Interaction States

| State | Pattern |
|-------|---------|
| Hover | `hover:bg-slate-50`, `hover:bg-slate-100` |
| Focus | `focus:ring-2 focus:ring-sky-500/50` |
| Disabled | `disabled:opacity-50 disabled:cursor-not-allowed` |
| Active Nav | `border-r-4 border-sky-600 bg-sky-50` |
| Expanded | `rotate-180` on chevron icon |

---

### Agent 5: Design & Branding (UI/UX Lead)

**ROLE:** Graphic designer and brand designer for ArkLine. Owns all visual aspects of the app including the design system, component styling, animations, and brand consistency.

**OWNS (can modify):**
```
/Core/Theme/Colors.swift
/Core/Theme/Typography.swift
/Core/Theme/Spacing.swift
/Core/Theme/Modifiers.swift
/Core/Theme/Gradients.swift
/Core/Theme/Shadows.swift
/Core/Theme/Animations.swift
/SharedComponents/
/Features/*/Views/*.swift (visual styling only)
```

**READ ACCESS (for visual auditing):**
```
/Features/*/Views/          (all feature views)
/Users/matt/Downloads/arkline_admin-main/  (Julia's reference)
```

**RESPONSIBILITIES:**

| Area | Responsibility |
|------|----------------|
| **Design System** | Colors, typography, spacing, shadows, gradients |
| **Components** | SharedComponents library, reusable UI elements |
| **Visual Polish** | Animations, transitions, micro-interactions |
| **Glassmorphism** | Glass card effects, blur, overlays |
| **Brand Consistency** | Ensure all screens match ArkLine brand |
| **Light/Dark Mode** | Adaptive theming across all components |
| **Accessibility** | Color contrast, tap targets, VoiceOver labels |
| **Icons & Assets** | Icon styling, image treatments |

**DESIGN AUTHORITY:**
- Agent 5 has FINAL SAY on all visual decisions
- Other agents must use design tokens from `/Core/Theme/`
- Other agents request new components via Agent 5
- Agent 5 can modify View files for styling (not logic)

**COORDINATION WITH OTHER AGENTS:**

| Agent | Coordination |
|-------|--------------|
| Agent 1-3 | They handle logic, Agent 5 handles visuals |
| All | Must use Agent 5's design tokens, no hardcoded values |

**WORKFLOW:**
1. Review Julia's admin panel for reference patterns
2. Audit current iOS app styling
3. Identify inconsistencies and gaps
4. Update design system tokens
5. Polish components and views
6. Ensure brand consistency across all screens

---

## Restricted Files (Require User Approval)

These files should not be modified without explicit user approval:

```
/Core/Utilities/Constants.swift     (API keys, URLs)
/.gitignore
/ArkLine.xcodeproj/                 (project settings)
```

---

## Design System Standards

All agents MUST follow these branding guidelines:

### Colors (from `/Core/Theme/Colors.swift`)

| Token | Value | Usage |
|-------|-------|-------|
| `primary()` | #3369FF / #3B69FF | Primary actions, links |
| `success()` | #22C55E | Positive changes, confirmations |
| `warning()` | #F59E0B | Cautions, alerts |
| `error()` | #EF4444 | Errors, negative changes |
| `background()` | #0F0F0F (dark) / #F5F5F5 (light) | Screen backgrounds |
| `surface()` | #0A0A0B (dark) / #FFFFFF (light) | Card backgrounds |

**Usage:**
```swift
// CORRECT - Always pass ColorScheme
ArkColors.primary(for: colorScheme)
ArkColors.background(for: colorScheme)

// INCORRECT - Never hardcode
Color(hex: "#3369FF")  // NO!
Color.blue             // NO!
```

### Typography (from `/Core/Theme/Typography.swift`)

| Style | Font | Size | Usage |
|-------|------|------|-------|
| `.largeNumber` | Inter Bold | 64pt | Portfolio value |
| `.heroNumber` | Inter Bold | 44pt | Large metrics |
| `.largeTitle` | Urbanist Medium | 32pt | Screen titles |
| `.headline` | Urbanist Medium | 20pt | Section headers |
| `.body` | Inter Regular | 16pt | Body text |
| `.caption` | Inter Regular | 12pt | Secondary text |

**Usage:**
```swift
Text("$125,432.67")
    .font(ArkTypography.largeNumber)
```

### Spacing (from `/Core/Theme/Spacing.swift`)

| Token | Value | Usage |
|-------|-------|-------|
| `.xxs` | 4pt | Tight spacing |
| `.xs` | 8pt | Icon padding |
| `.sm` | 12pt | Small gaps |
| `.md` | 16pt | Standard padding |
| `.lg` | 20pt | Section spacing |
| `.xl` | 24pt | Large gaps |
| `.xxl` | 32pt | Screen margins |

### Modifiers

```swift
// Glass card effect
.glassCard()

// Glowing button
.glowButton()

// Standard shadows
.arkShadow(.small)
.arkShadow(.medium)
.arkShadow(.large)
```

### Corner Radius

| Token | Value | Usage |
|-------|-------|-------|
| `.small` | 8pt | Buttons, inputs |
| `.medium` | 12pt | Cards |
| `.large` | 16pt | Large cards, sheets |

---

## Architecture Patterns

All agents MUST follow these patterns:

### ViewModels
```swift
@Observable
class FeatureViewModel {
    // Dependencies
    private let service: ServiceProtocol

    // State
    var isLoading = false
    var errorMessage: String?
    var data: [Model] = []

    init() {
        self.service = ServiceContainer.shared.serviceInstance
    }

    func loadData() async {
        isLoading = true
        defer { isLoading = false }

        do {
            data = try await service.fetchData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
```

### Views
```swift
struct FeatureView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewModel = FeatureViewModel()

    var body: some View {
        // Always use design system tokens
        VStack(spacing: ArkSpacing.md) {
            // Content
        }
        .background(ArkColors.background(for: colorScheme))
    }
}
```

### Services
```swift
protocol FeatureServiceProtocol {
    func fetchData() async throws -> [Model]
}

final class APIFeatureService: FeatureServiceProtocol {
    private let networkManager: NetworkManager

    func fetchData() async throws -> [Model] {
        // Implementation
    }
}
```

---

## Cross-Agent Communication

### Requesting Changes from Another Agent

If you need a change in another agent's domain:

1. **Add a TODO comment in your code:**
```swift
// TODO: [Agent 3] - Need new CryptoAlert model with fields: id, assetId, targetPrice, isAbove
// Temporary workaround below until model is available
```

2. **Continue with your work** using temporary solutions if possible

3. **Document the dependency** so it can be resolved

### Requesting New Models (Agent 3)

Format your request clearly:
```
MODEL REQUEST: CryptoAlert
Fields:
- id: UUID
- assetId: String
- targetPrice: Double
- isAbove: Bool
- createdAt: Date
- isActive: Bool

Usage: Price alert notifications in Portfolio feature
```

### Requesting New SharedComponents (Agent 3)

Format your request clearly:
```
COMPONENT REQUEST: PriceAlertBadge
Props:
- price: Double
- isAbove: Bool
- isActive: Bool

Design: Small pill badge showing alert status
Usage: Display on asset cards when alert is set
```

---

## Git Workflow

### Commit Message Format
```
[Domain] Brief description

Examples:
[Portfolio] Add transaction history view
[Market] Fix sentiment gauge animation
[Core] Add new PriceAlert model
[Core] Update glass card opacity for light mode
```

### Before Starting Work
```bash
git pull origin main
git status
```

### Commit Frequently
- Commit after completing each logical unit of work
- Don't batch multiple features into one commit

---

## Conflict Resolution

### If You Accidentally Modify Another Agent's File

1. **Stop immediately**
2. **Revert your changes:** `git checkout -- <file>`
3. **Document what you needed** as a TODO
4. **Request the change** from the owning agent

### If Merge Conflicts Occur

1. **Do not resolve conflicts in files you don't own**
2. **Notify the owning agent**
3. **Let them resolve their own files**

---

## Quick Reference

| Need | Go To |
|------|-------|
| New color token | **Agent 5** (Core/Theme) |
| New typography style | **Agent 5** (Core/Theme) |
| New shared component | **Agent 5** (SharedComponents) |
| Visual polish/animations | **Agent 5** |
| Glassmorphism effects | **Agent 5** |
| Brand consistency | **Agent 5** |
| New model | Agent 3 (Domain/Models) |
| ServiceContainer update | Agent 3 |
| Network/API changes | Agent 3 |
| Portfolio feature logic | Agent 1 |
| DCA feature logic | Agent 1 |
| Market data feature | Agent 2 |
| AI Chat feature | Agent 2 |
| Community feature | Agent 2 |
| Home dashboard logic | Agent 3 |
| Settings/Profile logic | Agent 3 |
| Authentication logic | Agent 3 |
| Julia's design reference | Agent 5 (has read access) |

---

## Checklist Before Committing

- [ ] Only modified files in my ownership domain
- [ ] Used design system tokens (no hardcoded colors/spacing)
- [ ] Passed `colorScheme` to all color functions
- [ ] Used `@Observable` for ViewModels
- [ ] Used `async/await` for network calls
- [ ] Added TODO comments for cross-agent dependencies
- [ ] Commit message follows format: `[Domain] Description`

---

*Last updated: January 2026*
