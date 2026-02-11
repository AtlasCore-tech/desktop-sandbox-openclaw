# AtlasCore - Run OpenClaw without breaking your PC

## A Desktop Sandbox for OpenClaw
**AtlasCore** is a desktop sandbox which designed with seamless compatibility and robust isolation at its core, enables OpenClaw to operate with the same full functionality, responsiveness, and behavioral consistency as it does on a physical, unvirtualized operating system. 

This sandbox acts as a high-fidelity digital replica of a real desktop environment—mirroring the underlying OS architecture, system libraries, command-line interfaces, and permission frameworks—ensuring that every OpenClaw capability, from skill execution and system command invocation to policy management, performs identically to its behavior on a native system.

Supported OS: **macOS 12.6+** and **Windows 10/11**.

## Why this matters
- Prevent accidental or malicious overreach: AtlasCore reduces the blast radius if OpenClaw requests or executes unintended actions.
- Reduce leakage risk: OpenClaw only accesses and uses data within AtlasCore; local device data will not be damaged or leaked.
- Eliminate friction between OpenClaw and the host OS: OpenClaw can interact with simulated system resources, execute scripts, and modify execution policies exactly as it would on a real desktop—all without exposing the host system to risks associated with untrusted commands, arbitrary executable runs, or policy modifications
- Explore OpenClaw's full capabilities: AtlasCore empowers developers, testers, and users to explore OpenClaw's full capabilities—including high-risk operations like policy customization and executable testing—without compromising the integrity of their native environment.
- Peserve native essence while enhancing value: AtlasCore ensures that OpenClaw's power is never limited by security concerns, and that security is never achieved at the cost of functionality.
- Reduce costs: No need to purchase an additional Mac mini, reducing equipment investment.

## Install AtlasCore
- Download and execute AtlasCore.pkg or AtlasCore.exe.
- Complete the registration according to the wizard.
  ![9c4efbce0572f6b46f22a07347fd1d34](https://github.com/user-attachments/assets/217bc3f0-f4e4-48c4-ae66-167a21b939a3)

## Usage (macOS)
1. Log in to the AtlasCore client.
2. Add iTerm.app and chrome.app in AtlasCore desktop.
  ![6af5de1a30c4e32c86cbff73c4f8d9c8](https://github.com/user-attachments/assets/5a53b727-3fa5-44a2-ab05-bf112e2cb191)
3. Downlod OpenClaw sourcecode inside AtlasCore.
   <img width="1014" height="701" alt="1" src="https://github.com/user-attachments/assets/63fe8b41-ae08-4739-9119-c16e98ce6212" />
4. Prepare node ENV in AtlasCore.
   <img width="857" height="616" alt="2" src="https://github.com/user-attachments/assets/3ae0cdf8-557d-4df5-b29e-fbe1096831ee" />
5. Install depends using commands.
   ```bash
   pnpm install && pnpm run build   
   pnpm run clawdbot onboard
   ```
   Configue the LLM following the wizard.
6. Prepare the OpenClaw gateway running enviroment.
   <img width="893" height="603" alt="9" src="https://github.com/user-attachments/assets/1139bff2-1d11-4394-bfcb-cdb8e393e1f1" />
7. Start the gateway service.
   <img width="1649" height="729" alt="10" src="https://github.com/user-attachments/assets/ee20dafe-a5bb-4435-9155-ce88e8ee269e" />
8. Complete the deployment of OpenClaw.
   <img width="1399" height="1051" alt="11" src="https://github.com/user-attachments/assets/811d9e64-af50-4b4f-823f-b8077143cd34" />

## Contact
For questions about Atlascore, open an issue or contact the maintainers.
