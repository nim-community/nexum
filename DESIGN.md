# Design System: Helix
**Project ID:** helix-nim-framework

## 1. Visual Theme & Atmosphere

Helix is a compile-time reactive web framework for Nim. Its visual language communicates **precision through warmth** — the cold rigor of compiler engineering (macro expansion, isomorphic codegen, zero-JS static pages) wrapped in an approachable, editorial aesthetic that feels like reading a well-typeset technical journal.

The atmosphere is **warm minimalism with scholarly authority**. Generous whitespace creates confidence. A warm off-white canvas feels like aged parchment rather than sterile paper. Deep earthy accents (burnt sienna, forest teal) ground the interface in organic materiality. High-contrast serif headlines create editorial gravitas, while clean sans-serif body text ensures technical readability.

**Mood keywords**: editorial, engineered, organic warmth, precise, scholarly, confident whitespace

**Density**: Medium. Tight groupings inside components (cards, code blocks) contrast with generous breathing room between sections. Asymmetric left-aligned compositions feel intentional rather than mechanical.

---

## 2. Color Palette & Roles

### Primary Brand Colors

- **Burnt Sienna** (`#c25e00`): The primary action color — warm, earthy, and energetic without aggression. Used for primary buttons, links, interactive highlights, and the hero heading gradient. Evokes fired clay and autumn leaves.
- **Deep Forest Teal** (`#0d5c56`): The secondary accent — cool but grounded, used for badges, secondary emphasis, and technical metadata. Provides natural contrast to the sienna without visual competition.

### Surface & Canvas Colors

- **Aged Parchment** (`#faf8f5`): The primary canvas background — a warm off-white tinted subtly toward cream. Never pure white (`#ffffff`), which would feel too clinical. Creates subconscious comfort and reduces eye strain.
- **Warm Charcoal** (`#1c1917`): The primary text color — a deep, warm near-black with subtle brown undertones. Avoids the harshness of pure black (`#000000`).
- **Pressed Cream** (`#f5f0eb`): Elevated surface color for cards and contained sections — slightly darker than the canvas, creating gentle elevation through color shift rather than shadow.
- **Warm Stone Border** (`#e7e5e4`): Subtle divider and card border color — a warm gray that harmonizes with the parchment palette. Never cool-toned gray.

### Supporting Colors

- **Muted Stone** (`#78716c`): Secondary text, captions, and meta information — warm mid-tone gray that recedes quietly.
- **Warm Near-Black** (`#292524`): Code block backgrounds — deep enough for contrast against off-white code text, but warm enough to avoid the clinical feel of pure `#1a1a1a`.
- **Off-White Ink** (`#f5f5f4`): Code text color — warm white for maximum readability against the near-black code background.

### Gradient Usage

- **Hero Heading Gradient**: A 135-degree sweep from Burnt Sienna to Deep Forest Teal (`linear-gradient(135deg, #c25e00, #0d5c56)`), clipped to text shape via background-clip. Used sparingly — only for the main hero title — to create a singular brand moment.

---

## 3. Typography Rules

**Display / Headlines**: *Playfair Display* (Google Fonts) — a high-contrast transitional serif with sharp, precise details. Weight 700. Used for emotional authority and editorial gravitas. Aggressive negative letter-spacing (-0.02em) creates compressed, urgent headlines that feel engineered for impact.

**Body / UI Text**: *Source Sans 3* (Google Fonts) — a humanist sans-serif with open apertures and generous proportions. Weight 400 for body, 600 for emphasis. Clean, neutral, and highly legible at small sizes.

**Code / Technical**: *SF Mono*, Monaco, or *Cascadia Code* — monospace families reserved exclusively for code blocks, inline code spans, and interactive demo UI. Never used for headings or marketing copy.

**Type Scale** (fluid, scaling with viewport width):

| Purpose | Size | Weight | Letter Spacing | Line Height |
|---------|------|--------|----------------|-------------|
| Hero Title | `clamp(2.8rem, 5vw + 1rem, 5rem)` | 700 | -0.02em | 1.15 |
| Section Heading | `clamp(1.8rem, 3vw + 0.5rem, 2.8rem)` | 700 | -0.02em | 1.15 |
| Subsection | `clamp(1.1rem, 1.5vw + 0.5rem, 1.4rem)` | 700 | -0.01em | 1.2 |
| Body Text | `clamp(1rem, 0.95rem + 0.25vw, 1.125rem)` | 400 | normal | 1.65 |
| Labels / Badges | `0.75rem` | 600 | 0.08em | 1.5 |
| Code Blocks | `0.88rem — 0.95rem` | 400 | normal | 1.6 |

**Principles**:
- Headlines are always left-aligned. Centered headlines feel templated.
- Uppercase text is restricted to badges and small labels, paired with wide letter-spacing (0.08em) for breathability.
- Body text maintains generous line-height (1.65) for extended reading comfort.

---

## 4. Component Stylings

### Buttons

- **Shape**: Gently rounded corners (8px radius) — friendly but not playful.
- **Primary Fill**: Burnt Sienna background (`#c25e00`) with pure white text. No borders.
- **Hover State**: Darkens to a richer, more saturated sienna (`#9a4a00`) via a swift 150ms color transition.
- **Typography**: Monospace font at 0.9rem, creating a technical, console-like interaction feel.
- **Padding**: 0.5rem vertical, 1rem horizontal — compact but touchable.

### Cards / Containers

- **Shape**: Softly rounded corners (12px radius) — more generous than buttons, creating a containing, sheltering feel.
- **Background**: Pressed Cream (`#f5f0eb`) — elevated from the Aged Parchment canvas through color alone.
- **Border**: A hairline 1px stroke in Warm Stone Border (`#e7e5e4`) — barely perceptible, serving more as a soft edge definition than a strong boundary.
- **Shadow**: None at rest. On hover, a whisper-soft shadow appears (`0 8px 24px rgba(0,0,0,0.05)`) — so subtle it suggests floating rather than casting a shadow.
- **Hover Transform**: A gentle upward lift of 3 pixels (`translateY(-3px)`), paired with the shadow emergence. Transition duration: 200ms, ease curve.
- **Padding**: 1.5rem internal — generous internal breathing room.

### Inputs / Forms

- **Shape**: Gently rounded corners (8px radius), matching buttons for family cohesion.
- **Background**: Aged Parchment (`#faf8f5`) — sits flat against the canvas, not elevated.
- **Border**: 1.5px solid Warm Stone Border (`#e7e5e4`) — slightly heavier than card borders to indicate interactivity.
- **Focus State**: Border color shifts to Burnt Sienna (`#c25e00`) with no outline ring. The color change alone signals active state.
- **Typography**: Source Sans 3 at 0.95rem, Warm Charcoal text.
- **Padding**: 0.5rem vertical, 0.75rem horizontal.

### Badges / Pills

- **Shape**: Fully pill-shaped (999px radius) — organic, friendly, non-threatening.
- **Fill**: Transparent background with a 1.5px Warm Stone Border stroke.
- **Text**: Deep Forest Teal (`#0d5c56`), uppercase, 0.75rem, wide letter-spacing (0.08em).
- **Purpose**: Meta labels, status indicators, version tags.

### Code Blocks

- **Shape**: Softly rounded corners (10px radius) — slightly more organic than cards.
- **Background**: Warm Near-Black (`#292524`) — creates a dark room effect for code.
- **Text**: Off-White Ink (`#f5f5f4`) at 0.9rem, monospace.
- **Padding**: 1.25rem vertical, 1.5rem horizontal.
- **Syntax Highlighting** (warm palette only):
  - Keywords: Amber (`#f59e0b`)
  - Strings: Mint (`#a7f3d0`)
  - Comments: Warm Gray (`#a8a29e`)
  - Functions: Cyan (`#67e8f9`)
  - Numbers: Rose (`#fca5a5`)

---

## 5. Layout Principles

**Container Strategy**: A single, centered content column with a maximum width of 720px. This narrow measure creates an intimate, readable text block that feels like a journal page rather than a billboard.

**Horizontal Padding**: Fluid, viewport-responsive padding: `clamp(1.25rem, 4vw, 3rem)`. Comfortable on mobile, generous on desktop.

**Vertical Rhythm**:
- Section-to-section spacing: `clamp(3rem, 6vh, 5rem)` — dramatic breathing room between major ideas.
- Heading-to-content gap: 0.6em — tight coupling between label and content.
- Paragraph spacing: 1em — standard readable separation.

**Grid Strategy**: Feature cards use a responsive auto-fit grid (`repeat(auto-fit, minmax(240px, 1fr))`). Cards naturally reflow from 2 columns to 1 column on narrow viewports without explicit breakpoints.

**Alignment**: Predominantly left-aligned. Centered text is reserved exclusively for the hero section, creating a single moment of focus before the content unfolds in a natural left-to-right reading flow.

**Whitespace Philosophy**: Asymmetric and intentional. Tight internal spacing within components (cards, buttons) contrasts with generous external spacing between sections. This rhythm of compression and expansion guides the eye through the page hierarchy.

---

## 6. Depth & Elevation

Helix communicates depth through **color and warmth**, not through aggressive shadows.

| Level | Name | Treatment | Usage |
|-------|------|-----------|-------|
| 0 | Flat Canvas | No shadow, no border | Primary page background |
| 1 | Contained Surface | 1px solid Warm Stone Border | Cards, sections at rest |
| 2 | Whisper Float | `0 8px 24px rgba(0,0,0,0.05)` | Card hover states — barely visible |
| 3 | Focus Emphasis | Border color shifts to Burnt Sienna | Input focus, active selection |
| 4 | Gradient Depth | Text gradient clip | Hero title only — brand signature |

**Shadow Philosophy**: Shadows are extremely soft (0.05 opacity, 24px blur) and warm-tinted. They suggest gentle floating rather than harsh casting. The primary elevation mechanism is **background color shift** (Aged Parchment → Pressed Cream) rather than shadow.

---

## 7. Do's and Don'ts

**Do:**
- Use Aged Parchment (`#faf8f5`) as the universal canvas — never pure white.
- Tint every gray toward warmth — even subtle warm undertones create subconscious cohesion.
- Reserve the gradient text effect for the hero title only — it's a singular brand moment.
- Use Playfair Display's negative letter-spacing for compressed, engineered headlines.
- Maintain the tight-internal / generous-external spacing rhythm.
- Use the pill badge for meta information — its organic shape softens technical content.

**Don't:**
- Use cool grays (`#999`, `#cccccc`) — they visually detach from the warm palette.
- Use pure black (`#000000`) or pure white (`#ffffff`) — always tint toward warmth.
- Default to centered text outside the hero — left alignment feels more designed and readable.
- Use glassmorphism, blur effects, or neon glows — they feel decorative rather than purposeful.
- Use generic AI color palettes: cyan-on-dark, purple-blue gradients, neon accents.
- Put rounded-corner icons above every heading — creates a templated, interchangeable feel.

---

## 8. Responsive Behavior

**Breakpoint Strategy**: Fluid-first. Typography and spacing scale continuously via `clamp()` functions rather than jumping at discrete breakpoints.

**Mobile (< 640px)**:
- Hero title scales down to `2.8rem`.
- Card grid collapses to single column via `auto-fit`.
- Section padding reduces to minimum `1.25rem` horizontal.
- Touch targets maintain minimum 44px height.

**Tablet (640px — 1024px)**:
- Feature cards display in 2 columns.
- Hero title reaches mid-range `clamp` values.
- Container padding scales to `4vw`.

**Desktop (> 1024px)**:
- Feature cards may show 2 or more columns depending on container width.
- Hero title reaches maximum `5rem`.
- Container padding caps at `3rem`.

**Reduced Motion**:
```css
@media (prefers-reduced-motion: reduce) {
  * { animation: none !important; transition: none !important; }
}
```

---

## 9. Agent Prompt Guide

**Quick Color Palette Reference**:
- Canvas: `#faf8f5` (Aged Parchment)
- Text: `#1c1917` (Warm Charcoal)
- Primary Action: `#c25e00` (Burnt Sienna)
- Secondary Accent: `#0d5c56` (Deep Forest Teal)
- Elevated Surface: `#f5f0eb` (Pressed Cream)
- Border: `#e7e5e4` (Warm Stone)
- Code Background: `#292524` (Warm Near-Black)

**Ready-to-Use Prompts**:

> "Build a hero section with an Aged Parchment background, a Warm Charcoal subtitle, and a Burnt Sienna-to-Deep Forest Teal gradient headline. Use Playfair Display for the title and Source Sans 3 for body copy. Left-align all text."

> "Create a 2-column feature card grid. Cards have Pressed Cream backgrounds, softly rounded corners (12px), and a 1px Warm Stone border. On hover, they lift 3 pixels with a whisper-soft shadow. Use Source Sans 3 for card titles."

> "Style a code block with a Warm Near-Black background and warm syntax highlighting: amber for keywords, mint for strings, warm gray for comments. Use 10px corner radius and monospace typography."

> "Build an interactive demo with a signal counter and a live text input. Use the Burnt Sienna for the counter button, Deep Forest Teal for the character count meta, and monospace for the demo UI."
