Figma starter — Swipeat

This folder contains a ready-to-import starter skeleton for Figma. Use it to bootstrap a Figma file and share the link.

What you'll find:

- tokens/design-tokens.json  -> Design tokens compatible with the "Figma Tokens" plugin
- components/icons/*.svg     -> Small outline icons (heart, close, info, calendar, undo)
- components/food_card.svg    -> Example FoodCard placeholder (SVG)
- screens/*.svg              -> Simple wireframe SVGs for each of the 6 screens
- figma_pages.json           -> A manifest describing recommended Figma pages & components

How to use
1. In Figma, create a new file.
2. Install the "Figma Tokens" plugin (if not already) and import tokens/design-tokens.json.
   - Menu: Plugins → Development → Import plugin data (or use the plugin UI to import JSON)
3. Create Pages in Figma named: Tokens, Components, Screens.
4. Import SVGs: drag the files from this folder into the Figma file. Put icons under Components page and the screen SVGs under Screens.
5. Use the imported SVGs as the skeleton. Convert the screen SVGs into frames and replace placeholder rectangles with real images later.

Recommended Figma page structure
- Tokens (store colors, type styles, effects, spacings)
- Components (icons, button variants, FoodCard component)
- Screens (Onboarding, Swipe, Target, Loading, Plan, Recipe)

If you share the Figma link I can continue and flesh out components directly in the file (create components, instances, and export assets at 1x/2x/3x).

Notes
- The tokens file follows a simple Figma Tokens JSON shape. Your Figma Tokens plugin may expect slight format differences; it supports JSON import.
- SVG wireframes are intentionally simple and editable.


