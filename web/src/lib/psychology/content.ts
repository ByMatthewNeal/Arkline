// Psychology / Mindset content — parity with the iOS "Psychology" section.
// Copy mirrors ArkLine/Features/Market/Views/ReorderableMarketWidgetStack.swift
// and Domain/Models/HomeWidget.swift. Founder voice (Matthew Neal): honest,
// plain, motivational, for people building without a head start.

export type PrincipleCategoryKey = 'master' | 'crowd' | 'downside' | 'simple';

export interface PrincipleCategory {
  key: PrincipleCategoryKey;
  title: string;
  subtitle: string;
}

export interface Principle {
  category: PrincipleCategoryKey;
  title: string;
  body: string;
}

export interface Book {
  title: string;
  author: string;
  note: string;
}

export interface Rhythm {
  name: string;
  guide: string;
}

export const MINDSET_INTRO =
  `The last market you'll master is the one in your own head. Get that right and fear and greed stop running your money. Nobody sat most of us down and taught this, so we're teaching it here.`;

export const CATEGORIES: PrincipleCategory[] = [
  { key: 'master', title: 'Master Yourself', subtitle: 'The real work' },
  { key: 'crowd', title: 'Read the Crowd', subtitle: `Don't be a follower` },
  { key: 'downside', title: 'Protect the Downside', subtitle: 'Survive first' },
  { key: 'simple', title: 'Keep It Simple', subtitle: 'Cut the noise' },
];

export const PRINCIPLES: Principle[] = [
  // Master Yourself
  { category: 'master', title: 'Master yourself, not the market', body: `You can't delete fear, greed, or the itch to chase what everybody else is chasing. That's just being human. But you can catch it, name it, and choose not to move on it. Being able to sit with the feeling and not obey it is worth more than any chart.` },
  { category: 'master', title: 'Decide before the emotion arrives', body: `Make the plan while your head is clear, then let it run. Because in the moment, when everything is green or everything is red, you are not thinking, you are reacting. And the crowd's fear or greed will make the call for you if you didn't make it first.` },
  { category: 'master', title: 'Pain is a poor estimator of probability', body: `Nothing goes up forever and nothing goes down forever. A drop that feels like the end of the world is usually just a number you have lived through before and came out the other side of. The pain is loud, but it is not accurate.` },
  { category: 'master', title: `It's a human problem, not a technical one`, body: `Most people who lose aren't losing because they missed some indicator. They lose because of how they act when it gets hard. You don't need another tool. You need to get right with yourself first.` },
  { category: 'master', title: `Your mind invents patterns that aren't there`, body: `Your brain is built to find shapes in the noise, even when there's nothing there. Sometimes that clean setup you swear you see is just your own head telling you what you want to hear. Slow down and make sure it's real.` },
  { category: 'master', title: 'Make money, not right', body: `Your ego wants to be right. Your account only cares that you made money. Those two are not the same thing. Let go of needing to prove you were correct and it gets a lot easier to walk away from a bad position.` },
  { category: 'master', title: 'Know your own worst habits', body: `The edge isn't knowing more, it's knowing yourself. Get honest about where you slip up, the revenge trade, the panic sell, the FOMO buy, and put something in place that stops you before you get there.` },

  // Read the Crowd
  { category: 'crowd', title: 'The crowd is loudest before it is wrong', body: `FOMO is just the herd dressed up in a suit. When everybody's sure, when the whole feed is celebrating, that noise is the warning sign, not the green light.` },
  { category: 'crowd', title: 'Bottoms are courage, tops are discipline', body: `The best buys feel terrible and the best sells feel amazing. Safety and opportunity rarely sit in the same seat, so the moves that actually matter almost never feel good while you're making them.` },
  { category: 'crowd', title: 'Familiar is not the same as safe', body: `We pile into what we know, our own country's market, the coin our friends talk about, the names we recognize. Familiar feels safe, but a lot of the time it's just all your eggs in one basket wearing a comfortable face.` },
  { category: 'crowd', title: `A great company isn't always a great investment`, body: `A great company and a great investment are not the same thing. When everybody already knows a company is winning, that news is baked into the price. Pay too much for a good story and the math still has to work. The price you pay is what protects you.` },

  // Protect the Downside
  { category: 'downside', title: 'Protect first, profit second', body: `Size everything so one bad day can't take you out and no single loss can make you want revenge. Staying in the game long enough to let it compound beats swinging for the fences and striking out.` },
  { category: 'downside', title: 'A paper loss is not a real loss', body: `A red day is just ink on a screen. It doesn't become real until you sell it, or until the thing you own is actually broken. In a spread-out portfolio with no borrowed money, the dip isn't what hurts you. Panicking into it is.` },
  { category: 'downside', title: `Don't chase a loss`, body: `After you take a hit, everything in you wants to bet bigger and win it back fast. That's the exact move that turns a small hole into a deep one. The way out is slow and boring, never a desperate swing.` },
  { category: 'downside', title: 'Only play games you can win', body: `Some of the worst losses come from playing a game you had no business in. If you can't explain what you own or roughly what it's worth, you're not investing, you're hoping. Stay in your lane. It doesn't have to be a big lane, it just has to be honest.` },

  // Keep It Simple
  { category: 'simple', title: 'Patience is a position', body: `The market moves money from people in a hurry to people who can wait. Most days the strongest thing you can do, and the hardest, is nothing at all.` },
  { category: 'simple', title: 'Activity is not progress', body: `Doing more feels like working harder, but the people who trade the most usually end up with the least. Fees and bad timing quietly eat it all. Sitting still and letting it compound is the move nobody posts about.` },
  { category: 'simple', title: 'Subtract to see clearly', body: `Most of the edge comes from taking things away, not piling more on. Cut the noise, the fifty tabs, the loud voices, and focus on the few things that actually move the needle.` },
  { category: 'simple', title: 'Simple is not the same as easy', body: `A rule can fit in one sentence and still take you years to actually live by. The hard part was never understanding it. The hard part is doing it when it counts.` },
  { category: 'simple', title: 'Invert: dodge the obvious mistakes', body: `You don't have to be a genius. It's a lot easier to just avoid being a fool. Before you ask how to win, ask how you'd blow it, then don't do those things. That alone keeps you ahead of most people.` },
  { category: 'simple', title: `You can't predict, you can only prepare`, body: `Nobody knows what happens next. Anybody telling you they do is usually just talking their own book. You can't control the move, but you can control how ready you are for it.` },
];

export const BEATS: { line: string; tag: string }[] = [
  { line: `Bottoms come wrapped in bad news. That's exactly what makes them bottoms.`, tag: 'On buying fear' },
  { line: `Tops feel like the start of something huge, right when the smart money is quietly heading for the door.`, tag: 'On selling greed' },
  { line: `A red day is a paper loss. It only becomes real when you sell it, or when the thing you own is actually broken.`, tag: 'On loss aversion' },
  { line: `The loudest fear and the deepest value usually show up together. You don't have to be brave, just calm.`, tag: 'On capitulation' },
  { line: `Comfort and opportunity rarely sit in the same seat. If a buy feels safe, the easy money is usually gone.`, tag: 'On conviction' },
  { line: `The market doesn't know or care what you paid. Waiting to get back to even has trapped more people than any crash.`, tag: 'On anchoring' },
  { line: `Nothing goes up forever and nothing goes down forever. The pain is loud, but it's not accurate.`, tag: 'On recency bias' },
  { line: `The market moves money from people in a hurry to people who can wait. Most days the strongest move is to do nothing.`, tag: 'On patience' },
  { line: `You can't dig your way out of a hole. Protect first, profit second.`, tag: 'On revenge trades' },
  { line: `Make the plan while your head is clear. In the moment, the crowd's fear or greed will decide for you.`, tag: 'On preparation' },
  { line: `A feed full of people who agree with you is a warning, not a green light.`, tag: 'On confirmation bias' },
  { line: `You can't out-willpower your own brain in the moment. Decide when you're calm, then automate it so emotion gets no vote.`, tag: 'On rules over willpower' },
  { line: `You don't need to do more. Most days you need to do less.`, tag: 'On focus' },
  { line: `Before you ask how to win, ask how you'd blow it, then don't do that.`, tag: 'On discipline' },
  { line: `If you can't explain why you own it, you don't.`, tag: 'On conviction' },
  { line: `Survive first. You can't compound if you're out of the game.`, tag: 'On risk' },
  { line: `The quiet you protect is where the real thinking happens.`, tag: 'On focus' },
  { line: `The goal is to make money, not to be right.`, tag: 'On ego' },
  { line: `Nobody knows the next move. Anybody who says they do is talking their own book.`, tag: 'On humility' },
  { line: `Practice makes permanent, so repeat the right habit, not the comfortable one.`, tag: 'On discipline' },
  { line: `Smart people lose by thinking like everybody else.`, tag: 'On independence' },
  { line: `A loss hurts about twice as much as the same win feels good. Plan for it.`, tag: 'On loss aversion' },
  { line: `You remember your wins bigger than they really were.`, tag: 'On honesty' },
  { line: `Your mood is not market information.`, tag: 'On awareness' },
  { line: `Check less. Daily noise isn't a signal.`, tag: 'On focus' },
  { line: `Zoom out before you decide: the full cost, the long game, the other side of it.`, tag: 'On clarity' },
  { line: `Fear and hope usually point the wrong way. You fear losing a win, and hope keeps you in a bad position.`, tag: 'On awareness' },
  { line: `"The chart made me do it" is usually the ego dodging the pain of being wrong.`, tag: 'On ego' },
];

export function beatOfTheDay(): { line: string; tag: string } {
  const day = Math.floor(Date.now() / 86_400_000);
  return BEATS[day % BEATS.length];
}

export const READING_INTRO =
  `The books that shaped how I think about markets, money, and myself. If all you've got right now is the will to learn, start here.`;

export const BOOKS: Book[] = [
  { title: 'Best Loser Wins', author: 'Tom Hougaard', note: `The one who learns to lose well is the one who ends up winning. It's about controlling your own reactions, not calling the chart right.` },
  { title: 'The Psychology of Money', author: 'Morgan Housel', note: `Doing well with money has almost nothing to do with how smart you are. It's about how you behave when it's on the line.` },
  { title: 'The 10X Rule', author: 'Grant Cardone', note: `Aim way higher than feels reasonable, then put in the work to match. Most people aim too low and move too slow.` },
  { title: 'Who Not How', author: 'Dan Sullivan & Dr. Benjamin Hardy', note: `Stop trying to do everything yourself. Growth comes faster from finding the right people than from grinding alone.` },
  { title: 'Mastery', author: 'Robert Greene', note: `Mastery isn't talent, it's time and reps. A look at how the greats actually got there, one patient day at a time.` },
  { title: 'Thinking in Bets', author: 'Annie Duke', note: `Treat every choice like a bet with the odds unknown. Judge yourself on the decision, not just how it turned out, because good calls can still lose.` },
  { title: 'The Lords of Easy Money', author: 'Christopher Leonard', note: `How years of cheap money reshaped the markets and the risks. It's the backstory to why liquidity drives so much of what we watch.` },
  { title: 'Atomic Habits', author: 'James Clear', note: `Small habits stacked over time beat big bursts of motivation. Build the system and the results follow.` },
  { title: 'Thinking, Fast and Slow', author: 'Daniel Kahneman', note: `The two ways your brain makes decisions, and the blind spots hiding in both. A map of the traps your own mind sets for you.` },
  { title: 'Ego Is the Enemy', author: 'Ryan Holiday', note: `Ego trips you up on the way up, at the top, and after a fall. Humility and self-awareness are what keep you growing.` },
  { title: 'Richer, Wiser, Happier', author: 'William Green', note: `Fifty of the greatest investors alive on how they win, in markets and in life. The lesson underneath it all: keep it simple, stay steady, don't beat yourself.` },
  { title: 'The Psychology of Investing', author: 'John R. Nofsinger', note: `A plain-English look at the biases quietly costing you money, overconfidence, loss aversion, mental accounting, and how to build around them.` },
];

export const BALANCE_INTRO =
  `Investing is supposed to buy you a life, not become your life. It's an avenue to where you're trying to go, not who you are. Here's how to keep it in its place.`;

export const RHYTHMS: Rhythm[] = [
  { name: 'Set and forget', guide: `You've got a plan and it's on autopilot. A few minutes a week is plenty. That's most people, and there's no shame in it. Boring is a strategy.` },
  { name: 'Check in', guide: `You like staying in the loop. A couple of short check-ins a week keeps you informed without letting the noise run you.` },
  { name: 'Hands on', guide: `You're active and you enjoy it. Fine, but set a start and a stop time and protect the rest of your day. More screen time is not more returns.` },
];

export const RHYTHM_DEFAULT =
  `More time staring at charts doesn't make you more money. Past a point, it just makes you more anxious.`;

export const OVERDOING_SIGNS: string[] = [
  `It's the first thing you check in the morning and the last thing at night.`,
  `A green day or a red day decides your whole mood.`,
  `You're refreshing prices on your day off, at dinner, around the people you love.`,
  `Sleep, work, or relationships are slipping so you can watch a screen.`,
];

export const OVERDOING_NOTE =
  `If a few of these hit home, that's not a failure. It's a signal to step back.`;

export const BALANCE_CLOSER =
  `Build the wealth so you can live the life. Don't trade the life to watch the wealth.`;
