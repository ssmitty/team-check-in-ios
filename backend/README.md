# Server pairing module

Purpose: Prepare the assignment algorithm independently of hosted backend access.

Run tests with Node.js 22 or newer:

```sh
node --test backend/pairing.test.mjs
```

The server module takes already-authorized eligible member IDs and the previous event's groups. It shuffles the roster with cryptographic randomness, forms pairs or one trio, and counts repeated teammate relationships.

For up to 18 players it finds a matching with the minimum repeated relationships. Larger rosters use up to 512 randomized attempts and return whether optimality is known; a zero-repeat result is optimal. This bounds server work instead of promising an exhaustive search for an arbitrarily large roster.

The module is not deployed or connected to the app. Its caller still needs membership authorization, an event lock, atomic persistence, retry-safe assignment reuse, and scheduling. The SwiftUI prototype uses supplied sample assignments, not this server module.
