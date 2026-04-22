PlayCover Minecraft DMG

What this DMG gives you:
- A source-built custom PlayCover.app to drag into /Applications
- Safe Minecraft-specific support files in Extras/

What you still need:
- A decrypted Minecraft Bedrock IPA for iOS/iPadOS
- An Apple Silicon Mac

Recommended flow:
1. Drag PlayCover.app into Applications
2. If macOS blocks it, right-click PlayCover.app -> Open once
3. Run Install Minecraft IPA.sh and select your Minecraft IPA
4. Launch Minecraft

Manual fallback:
- Import/install Minecraft in PlayCover yourself
- Then run Extras/apply-minecraft-working-state.sh

Notes:
- This package does not include Minecraft itself or a decrypted IPA
- This package does not include PlayChain/auth DB state
- The helper scripts derive user-specific paths at install time
- The working-state overlay reuses the PlayTools framework already embedded in this app
- If macOS blocks the app, right-click -> Open or use Privacy & Security -> Open Anyway
