# UX Spec Generation Template

> **Purpose:** Instructions for an AI agent to generate a detailed, consistent UX specification from the codebase. Run this against the code whenever you need a shareable snapshot of the app's current state.

## How to Use

Give an AI agent with codebase access this prompt:

```
Read docs/UX_SPEC_TEMPLATE.md, then follow its instructions to generate a complete UX spec for the app. Output a single markdown document.
```

---

## Generation Instructions

### Sources to Read

1. **Router:** `lib/core/router/` — all screens, routes, and navigation structure
2. **Pages:** `lib/features/*/presentation/pages/` — every screen's layout and behavior
3. **Key widgets:** `lib/features/*/presentation/widgets/` — reusable components, bottom sheets, dialogs
4. **BLoC states/events:** `lib/features/*/presentation/bloc/` — all possible screen states
5. **Entities:** `lib/features/*/domain/entities/` — core data structures the user interacts with
6. **Theme:** `lib/core/theme/` — color system, typography scale
7. **Existing docs:** `docs/USER_GUIDE.md`, `docs/PRODUCT_OVERVIEW.md` — for context, not for copying

### Output Structure

Generate the spec with these sections in order:

#### 1. App Overview (1 paragraph)
- What the app does, target platform, primary use case

#### 2. Navigation Map
- Tab structure with icons and labels
- Route hierarchy (tree format)
- Which screens are modals/bottom sheets vs full pages

#### 3. Per-Screen Specification

For **every** screen/page in the app, document:

| Section | What to Include |
|---------|-----------------|
| **Screen name** | Class name and route path |
| **Purpose** | One sentence — what the user accomplishes here |
| **Entry points** | How the user gets to this screen (tab, button, route) |
| **Layout** | Top-to-bottom description of visual sections (app bar, body sections, FABs, bottom bars) |
| **Interactive elements** | Every tappable element: buttons, chips, toggles, text fields, list items. For each, state what it does. |
| **States** | All distinct visual states the screen can be in (loading, empty, populated, error, etc.) and what each looks like |
| **Validation** | Any input validation rules, required fields, character limits |
| **Dialogs & sheets** | Any modals, bottom sheets, or confirmation dialogs triggered from this screen. Include their content and actions. |

#### 4. Shared Components

Document reusable widgets that appear across multiple screens:
- Name, visual description, where it's used
- Configurable variants (e.g., filled vs outlined)

#### 5. Data Entities

For each user-facing entity (Item, Category, Event, etc.):
- Fields the user can see or edit
- Field types and constraints (e.g., "name: required, max 50 chars")
- Relationships (e.g., "an Item belongs to a Category")

#### 6. Theme & Styling

- Color palette: list semantic color names and their purpose
- Typography scale: list named styles and where each is used
- Dark/light mode behavior

### Detail Level Guidelines

- **Be specific:** "Tapping the FAB opens ItemFormPage in create mode" not "User can add items"
- **Include all states:** Don't skip empty states, error states, or loading states
- **Name every interactive element:** If it's tappable, document it
- **Quote actual text:** Use exact labels, button text, and placeholder text from the code
- **Skip implementation details:** Don't mention BLoC class names, state classes, or architecture patterns. Describe what the user sees and does, not how it's built.
- **Skip styling values:** Don't list padding, font sizes, or hex colors. Use semantic names (e.g., "primary color", "body text style").

### Formatting Rules

- Use markdown with consistent heading levels (H2 for sections, H3 for screens, H4 for subsections)
- Use tables for structured data (interactive elements, entity fields)
- Use bullet lists for states and entry points
- Keep descriptions concise — prefer sentence fragments over full paragraphs
- No emojis
