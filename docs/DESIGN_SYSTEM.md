# Interface conventions

Purpose: Define a small native visual system and accessible writing conventions for the SwiftUI prototype.

## Direction

Use the temporary working title "Team Check-in." Aim for a quiet, friendly sports-team experience with short screens and one primary action at a time. The app should make it easy to reach a person at warmups.

## Native components

- Use NavigationStack, TabView, List, Form, DatePicker, sheets, and system alerts.
- Use system text styles: largeTitle for entry, title2 for the main prompt, headline for card headings, body for responses, and footnote for supporting text.
- Use semantic system backgrounds and primary/secondary text colors for automatic dark-mode support.
- Use system teal as the initial accent, with selection expressed through a checkmark and text as well as color.
- Standard spacing values: 8, 12, 16, and 24 points. Use rounded cards sparingly, with 16-point corner radius.
- Use SF Symbols for icons. Feeling choices retain text labels, with optional symbols such as leaf, bolt, waveform, moon, and cloud.
- Use full-width primary actions where useful; retain native button behavior and at least a 44-point touch target.

## Accessibility

- Allow text to wrap and layouts to grow at accessibility text sizes. Do not truncate a teammate's note to make a fixed-height card fit.
- Avoid horizontal grids that force feeling labels into narrow columns. Use stacked choices or an adaptive layout.
- Expose selection state to VoiceOver. Do not depend on a border-color change alone.
- Give photo actions explicit labels, including Remove photo and Retry photo upload.
- Group related teammate information in a sensible reading order without hiding interactive actions inside a combined accessibility element.
- Announce loading, save failures, and successful sharing when appropriate. Respect Reduce Motion and avoid decorative animation or countdown urgency.
- Check light/dark mode and larger text on both the smallest supported iPhone and a larger iPhone before Phase 2 completion.

## Writing

Use plain, supportive language: "I've got you," "Check-in shared," "Try again," and "No game scheduled yet."

Avoid diagnosis, scores, performance guarantees, pressure to disclose, or language that implies a teammate must solve someone's feelings. Avoid reminders that call out nonparticipation publicly.

Do not include emoji characters or em dashes. Keep technical implementation details in documentation, except for the prototype's necessary demo label.

## Previews and review

Every SwiftUI view gets a preview with mock data. Include previews for empty, waiting, error, trio, and closed-window states where relevant. Preview availability alone does not establish that the interactive flow works.

Keep screenshots and verification evidence in `docs/images/` once a build runs. Do not fabricate screenshots or mark visual checks passed without inspection.
