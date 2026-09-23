# 🎓 OnVUE Exam Preparation Assistant

**A PowerShell WPF GUI tool to prepare your Windows system for Pearson VUE OnVUE online proctored exams**

---

## 📋 Executive Summary

Online proctored exams fail for technical reasons more often than they should — a background VM, a screen recorder, an open VPN, or a stray Teams call can be enough to delay or terminate a session. **OnVUE Exam Preparation Assistant** is a self-contained PowerShell/WPF application that scans your system for exactly the things Pearson VUE's OnVUE proctoring software cares about, and lets you clean them up with a few clicks — nothing closes or stops without your say-so.

**Key Features:**

- 🔍 **Pre-Flight Check** — scan everything with zero changes made
- ☑️ **Opt-in, not all-or-nothing** — every process and service is a checkbox you control
- 🖥️ **Live hardware checks** — monitor count, webcam, and microphone detection
- 🔐 **One-click elevation** — relaunch as Administrator without leaving the app
- 🚫 **High-risk software scan** — flags anything that will actively terminate your exam
- 🔄 **Session tracking & restore** — everything stopped can be restarted afterward
- 📝 **Exportable report** — save a full session log for your records

**Perfect for:** Students, certification candidates, and IT professionals taking Pearson VUE OnVUE proctored exams who want a predictable, low-drama way to get their system exam-ready.

> ⚠️ This is an **unofficial, community-built tool** and is not affiliated with, endorsed by, or connected to Pearson VUE.

---

## 📑 Table of Contents

- [Features](#-features)
- [Requirements](#-requirements)
- [Installation](#-installation)
- [Usage](#-usage)
- [Interface Overview](#️-interface-overview)
- [What Gets Closed / Stopped](#-what-gets-closed--stopped)
- [Safety Features](#️-safety-features)
- [Best Practices](#-best-practices)
- [Troubleshooting](#-troubleshooting)
- [Changelog](#-changelog)
- [Contributing](#-contributing)
- [Disclaimer](#️-disclaimer)
- [License](#-license)
- [Support](#-support)

---

## ✨ Features

### 🔍 Pre-Flight Check
Scans processes, services, and VPN status with **no changes made**, and populates the Processes and Services tabs so you can review everything before touching anything.

### ☑️ Opt-In Process & Service Control
Every detected process and service appears as a checkbox in a list, categorized as **Critical**, **Standard**, or **Office**. Nothing closes unless you select it (Critical items are pre-checked as a starting point; you can change that). Closing Office apps (Word/Excel/PowerPoint/Outlook) requires a separate confirmation since it risks unsaved work.

### 🛡️ High-Risk Software Scan
Specifically flags applications — VMs, screen recorders, remote-desktop tools, packet sniffers — that **will** cause exam termination if detected, with a clear red banner when found.

### 🌐 Optimize & VPN Tab
- VPN/TAP adapter detection (only flags adapters that are actually up)
- Temp file cleanup with an item count
- Network connectivity check
- One-click link to Windows' real Focus Assist settings (no unsupported registry hacks)

### 🖥️ Live System Checks
On the Summary tab: monitor count, webcam presence, and microphone presence, each with a pass/warn/fail indicator. (Webcam/mic detection is device-class and name based — a best-effort signal, not a hardware test.)

### 🔐 Self-Elevation
If launched without Administrator rights, a **Relaunch as Admin** button appears in the header and reopens the tool elevated via UAC — no need to close and manually restart it.

### 📝 Session Summary & Export
Tracks everything closed/stopped this session, lets you restore stopped services in one click, and exports a full text report (including the activity log) for your records.

### 📜 Activity Log
A persistent, timestamped log of every action taken, visible at all times at the bottom of the window.

---

## 💻 Requirements

- **Operating System**: Windows 10 or Windows 11
- **PowerShell**: Version 5.1 or higher (included with Windows)
- **.NET / WPF**: Included with Windows — no separate install
- **Permissions**: Administrator recommended for full functionality (required to stop/start services); the app will prompt you to relaunch elevated if needed

---

## 📥 Installation

### Option 1: Direct Download
1. Download `OnVue_System_Preperation.ps1` from this repository
2. Save it to a convenient location (e.g., `C:\Scripts\` or your Desktop)
3. Right-click the file and select **Run with PowerShell**

### Option 2: Git Clone
```powershell
git clone https://github.com/ChrisMunnPS/OnVue_System_Preperation.git
cd OnVue_System_Preperation
.\OnVue_System_Preperation.ps1
```

### Setting Execution Policy (if needed)
If Windows blocks the script from running:
```powershell
# Check current policy
Get-ExecutionPolicy

# Allow locally-created scripts for the current user (recommended)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Or allow for a single session only
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
```

---

## 🚀 Usage

### Quick Start
1. **Save all your open work** — the app will close applications you select
2. Run `.\OnVue_System_Preperation.ps1` (as Administrator for full functionality, or use **Relaunch as Admin** inside the app)
3. Go to the **Pre-Flight** tab and click **Run Pre-Flight Check**
4. Review what's found on the **Processes** and **Services** tabs, adjust checkboxes as needed
5. Click **Run Full Preparation** in the header for an end-to-end pass, or work through tabs individually
6. Check the **Summary** tab before starting your exam
7. After your exam, reopen the app and click **Restore Stopped Services**

### Recommended Workflow
```
1️⃣  Pre-Flight tab → Run Pre-Flight Check
     ↓
2️⃣  Save all open work manually
     ↓
3️⃣  Header → Run Full Preparation (confirm the prompt)
     ↓
4️⃣  Summary tab → Run System Checks, review final checklist
     ↓
5️⃣  Close the app
     ↓
6️⃣  Start your OnVUE exam
     ↓
7️⃣  After the exam: reopen → Summary tab → Restore Stopped Services
```

---

## 🖥️ Interface Overview

| Tab | Purpose |
|---|---|
| **Pre-Flight** | Read-only scan of processes, services, and VPN status |
| **Processes** | Checkbox list of detected processes by category; close selected |
| **Services** | Checkbox list of detected interfering services; stop selected (Admin required) |
| **Optimize & VPN** | VPN check, temp file cleanup, network check, Focus Assist link |
| **High-Risk Scan** | Dedicated scan for exam-terminating software, with a warning banner |
| **Summary & Export** | Session stats, live monitor/webcam/mic checks, service restore, report export, final checklist |
| **About** | Version and changelog |

---

## 🚫 What Gets Closed / Stopped

### 🔴 Critical Processes (pre-selected)
These will very likely interfere with proctoring:
- **Virtual Machines**: VMware, VirtualBox, Hyper-V (`vmms`/`vmcompute`), Docker
- **Screen Recording**: OBS, XSplit, Bandicam, Camtasia, Snagit, Fraps
- **Remote Desktop**: TeamViewer, AnyDesk, VNC, Chrome Remote Desktop, Parsec
- **Network Analysis**: Wireshark, Fiddler, Charles Proxy, Burp Suite

### 🟡 Standard Processes (opt-in)
Recommended to close but not selected by default:
- **Browsers**: Chrome, Firefox, Edge, Opera, Brave
- **Communication**: Teams, Slack, Discord, Zoom, Skype, WhatsApp, Telegram, Signal
- **Media**: Spotify, iTunes, VLC
- **Gaming**: Steam, Epic Games Launcher, Origin, Battle.net
- **Development**: VS Code, Notepad++, Sublime Text
- **Cloud Storage**: Dropbox, Google Drive, OneDrive
- **VPN Clients**: NordVPN, ExpressVPN, OpenVPN

### 🟣 Office Apps (opt-in, separately confirmed)
Word, Excel, PowerPoint, Outlook — only closed if you enable this and confirm, since it risks unsaved work.

### ⚙️ Services (Administrator required)
TeamViewer, AnyDesk, VNC, VMware, VirtualBox, Docker, NordVPN, ExpressVPN, OpenVPN, and EaseUS-related services, when actually running.

---

## 🛡️ Safety Features

- **Nothing closes without your selection** — checkboxes, not blanket actions
- **Separate confirmation for Office apps and for Full Preparation**
- **Graceful-then-forced close** — attempts a normal window close first, only force-kills if the app doesn't respond
- **Won't close itself** — skips the PowerShell process running the tool
- **Session tracking** — remembers everything closed/stopped so you can review or restore it
- **Exit warning** — if services are still stopped when you close the app, it asks first
- **No destructive data operations** — only closes processes and stops services (both reversible)

---

## 💡 Best Practices

**Before running:**
✅ Save all open work
✅ Run Pre-Flight Check first to see what will be affected
✅ Read the activity log for warnings

**During preparation:**
✅ Run as Administrator (or use Relaunch as Admin) for full functionality
✅ Stay connected to the internet
✅ Review the Processes/Services lists before closing — don't just accept every default

**Before starting your exam:**
✅ Check the Summary tab's live system checks (monitor, webcam, mic)
✅ Work through the final checklist
✅ Close the app itself before launching OnVUE

**After your exam:**
✅ Reopen the app and restore stopped services
✅ Restart your computer if anything seems off afterward

---

## 🔧 Troubleshooting

**"Execution of scripts is disabled on this system"**
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

**Services won't stop, or the Services tab is empty of options**
Run as Administrator — use the **Relaunch as Admin** button in the header, or right-click → *Run with PowerShell as Administrator*.

**Webcam or microphone shows "not detected" but you have one**
Detection is name/device-class based (via WMI), not a live hardware test — this is a known limitation, noted in the app itself. Verify manually, e.g. with OnVUE's own system check.

**A closed application reopens on its own**
It's likely set to auto-restart via a startup entry or a background service. Stop the related service on the Services tab, or check Task Manager → Startup.

**High-risk software won't close**
Close it through its own interface first, stop its service if listed, or restart your computer.

---

## 📝 Changelog

**1.1.0**
- Added live system checks (monitor count, webcam, microphone) to the Summary tab
- Added a "Relaunch as Admin" self-elevation button

**1.0.0**
- Full WPF GUI rewrite of the original console-menu script, including:
  - Fixed a VPN-detection operator-precedence bug that could false-positive on any VPN-named adapter regardless of status
  - Replaced the no-op "Focus Assist" step with a link to the real Windows settings page
  - Split Office apps into their own opt-in category with explicit confirmation
  - Removed service-list entries that never matched anything (OneDrive/Dropbox/Steam/Zoom aren't Windows services)
  - Corrected several process names (`msedge`, `sublime_text`, `Code`, `vmms`/`vmcompute` for Hyper-V)
  - Every close/stop action is opt-in via checkboxes instead of all-or-nothing
  - Added report export and an unrestored-services warning on exit

---

## 🤝 Contributing

**Reporting issues:** open a GitHub issue with your Windows version, what happened vs. what you expected, and any error messages.

**Suggesting features:** open an issue with the `enhancement` label describing the feature and why it'd help.

**Pull requests:**
1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

**Code standards:** follow PowerShell approved verbs (`Get-`, `Set-`, `Test-`, `Start-`, `Stop-`, etc.), comment non-obvious logic, and test on a real Windows machine before submitting.

---

## ⚠️ Disclaimer

**This tool is provided as-is, without warranty of any kind.**

- **Unofficial** — not affiliated with, endorsed by, or connected to Pearson VUE
- The author is not responsible for issues arising from its use
- Always follow official Pearson VUE system requirements and guidance
- **Test this tool ahead of time**, not for the first time on exam day
- Some legitimate processes may be closed — review selections before confirming
- Intended for use on personal computers you control

---

## 📄 License

Licensed under the MIT License — see [LICENSE](https://github.com/ChrisMunnPS/OnVue_System_Preperation/blob/main/LICENSE) for details.

---

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/ChrisMunnPS/OnVue_System_Preperation/issues)
- **Discussions**: [GitHub Discussions](https://github.com/ChrisMunnPS/OnVue_System_Preperation/discussions)
- **Official OnVUE Support**: [Pearson VUE Support](https://home.pearsonvue.com/onvue)

---

## ⭐ Star This Repository

If this tool helped you get exam-ready with less stress, a star helps others find it.

---

**Good luck on your exam! 🍀**