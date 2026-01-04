# 🎓 OnVUE System Preparation Script

**A PowerShell utility to prepare your Windows system for Pearson VUE OnVUE online proctored exams**

## 📋 Executive Summary

Taking an online proctored exam can be stressful, especially when technical issues prevent you from starting on time. This script automates the tedious process of closing interfering applications, stopping conflicting services, and preparing your Windows system for Pearson VUE's OnVUE proctoring software.

**Key Features:**
- 🔍 **Safe Pre-Flight Check** - Scan your system without making any changes
- 🎯 **Targeted Cleanup** - Choose between critical-only or comprehensive preparation
- 🛡️ **Safety First** - Confirms before closing processes, attempts graceful shutdown
- 🔄 **Service Restoration** - Easily restart services after your exam
- ✅ **Final Checklist** - Ensures you haven't missed anything before starting

**Perfect for:** Students, IT professionals, and anyone taking Pearson VUE OnVUE proctored exams who want to minimize technical issues and start their exam with confidence.

---

## 📑 Table of Contents

- [Features](#-features)
- [Requirements](#-requirements)
- [Installation](#-installation)
- [Usage](#-usage)
- [Menu Options](#-menu-options)
- [What Gets Closed/Stopped](#-what-gets-closedstopped)
- [Safety Features](#-safety-features)
- [Best Practices](#-best-practices)
- [Troubleshooting](#-troubleshooting)
- [Contributing](#-contributing)
- [Disclaimer](#-disclaimer)
- [License](#-license)

---

## ✨ Features

### 🔍 Pre-Flight Check Mode
Run a complete system scan without making any changes. See exactly what processes and services are running that might interfere with your exam.

### 🎯 Flexible Preparation Options
- **Critical Only** - Close only the most problematic applications (VMs, screen recorders, remote desktop)
- **Comprehensive** - Close all potentially interfering applications
- **Custom** - Pick and choose which preparation steps to run

### 🛡️ Safety Mechanisms
- **User Confirmation** - Asks before making system changes
- **Graceful Shutdown** - Tries to close applications normally before force-killing
- **Session Tracking** - Remembers what was closed/stopped for easy restoration
- **Skip Current Script** - Won't close its own PowerShell process

### 📊 Visual Feedback
- Color-coded messages (Success, Warning, Error, Info)
- Progress indicators for each operation
- Clear summary of actions taken
- Professional menu interface

### 🔄 Post-Exam Restoration
Easily restart all services that were stopped during preparation with a single menu option.

---

## 💻 Requirements

- **Operating System**: Windows 10 or Windows 11
- **PowerShell**: Version 5.1 or higher (comes with Windows)
- **Permissions**: Administrator privileges recommended (not required for basic functions)
- **Execution Policy**: May need to be adjusted to run scripts

---

## 📥 Installation

### Option 1: Direct Download

1. Download the script file `OnVUE-Prep.ps1` from this repository
2. Save it to a convenient location (e.g., `C:\Scripts\` or your Desktop)
3. Right-click the file and select "Run with PowerShell" **as Administrator**

### Option 2: Git Clone

```bash
git clone https://github.com/yourusername/onvue-system-prep.git
cd onvue-system-prep
```

Then run with PowerShell as Administrator:

```powershell
.\OnVUE-Prep.ps1
```

### Setting Execution Policy (if needed)

If Windows prevents you from running the script, you may need to adjust the execution policy:

```powershell
# Check current policy
Get-ExecutionPolicy

# Allow scripts for current user (recommended)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Or allow for single session only
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
```

---

## 🚀 Usage

### Quick Start

1. **Save all your work** - The script will close applications
2. **Right-click PowerShell** and select "Run as Administrator"
3. **Navigate to the script location**:
   ```powershell
   cd C:\Path\To\Script
   ```
4. **Run the script**:
   ```powershell
   .\OnVUE-Prep.ps1
   ```
5. **Start with Option 1** (Pre-Flight Check) to see what needs attention
6. **Choose Option 7** for full preparation when ready

### Recommended Workflow

```
1️⃣ Option 1: Pre-Flight Check
    ↓
2️⃣ Manually save all open work
    ↓
3️⃣ Option 7: Full Preparation
    ↓
4️⃣ Option 9: View Summary
    ↓
5️⃣ Close PowerShell window
    ↓
6️⃣ Start OnVUE exam
    ↓
7️⃣ After exam: Run script again → Option 8: Restore Services
```

---

## 🎛️ Menu Options

```
1. Run Pre-Flight Check (Safe - No Changes)
   → Scans system and reports what's running without making changes
   → Perfect for first-time users to see what the script will do

2. Close Critical Processes Only (Recommended)
   → Closes VMs, screen recorders, remote desktop, packet sniffers
   → Quick and focused on the most problematic software

3. Close All Interfering Processes (Comprehensive)
   → Closes browsers, communication apps, media players, and more
   → Most thorough option for maximum compatibility

4. Stop Interfering Services
   → Temporarily stops background services
   → Requires Administrator privileges

5. Optimize System (Notifications, Temp Files)
   → Clears temporary files
   → Checks network connectivity
   → Provides guidance on Focus Assist

6. Check for High-Risk Software
   → Scans for software that WILL cause exam termination
   → Provides critical warnings if detected

7. Full Preparation (All Tasks)
   → Runs options 1-6 in sequence
   → Comprehensive preparation for your exam

8. Restore Stopped Services
   → Restarts services that were stopped during this session
   → Run after your exam is complete

9. View Preparation Summary
   → Shows what was done during this session
   → Displays final pre-exam checklist

0. Exit
   → Closes the script
```

---

## 🚫 What Gets Closed/Stopped

### Critical Processes (High Priority)
These **WILL** cause exam issues if running:

- **Virtual Machines**: VMware, VirtualBox, Hyper-V, Docker
- **Screen Recording**: OBS, XSplit, Bandicam, Camtasia, Fraps
- **Remote Desktop**: TeamViewer, AnyDesk, VNC, Chrome Remote Desktop
- **Network Analysis**: Wireshark, Fiddler, Charles Proxy

### Standard Processes (Should Close)
These applications may interfere:

- **Browsers**: Chrome, Firefox, Edge, Opera, Brave
- **Communication**: Teams, Slack, Discord, Zoom, Skype
- **Media**: Spotify, iTunes, VLC
- **Gaming**: Steam, Epic Games, Origin
- **Development**: VS Code, Visual Studio, IntelliJ
- **Cloud Storage**: Dropbox, OneDrive, Google Drive
- **VPN Clients**: NordVPN, ExpressVPN, OpenVPN
- **Office Apps**: Word, Excel, PowerPoint, Outlook

### Services Stopped
Background services that may conflict:

- Remote desktop services
- Cloud sync services
- Virtual machine services
- VPN services
- Gaming platform services
- Backup software services

---

## 🛡️ Safety Features

### User Confirmation
The script asks for confirmation before:
- Closing processes
- Stopping services
- Running full preparation

### Graceful Shutdown
For each process:
1. First attempts to close the application normally (allowing save prompts)
2. Waits 750ms for graceful exit
3. Only force-kills if the application refuses to close

### Protection Mechanisms
- **Won't close itself** - Skips the PowerShell process running the script
- **Error handling** - Continues if individual operations fail
- **Detailed logging** - Shows exactly what succeeded and what failed
- **No data modification** - Only closes processes and stops services (reversible)

### Session Tracking
The script remembers:
- Which processes were closed
- Which services were stopped
- Allows easy restoration after your exam

---

## 💡 Best Practices

### Before Running the Script

✅ **Save all your work** - The script will close applications without additional warning

✅ **Close applications manually first** - It's safer to close apps yourself when possible

✅ **Run Pre-Flight Check** - Use Option 1 to see what will be affected

✅ **Read the output** - Pay attention to warnings and errors

### During Preparation

✅ **Run as Administrator** - Provides full functionality

✅ **Stay connected** - Don't disconnect your internet during preparation

✅ **Don't rush** - Review each step and its results

### Before Starting Your Exam

✅ **Run Option 9** - Review the final checklist

✅ **Close PowerShell** - Don't leave the script running during your exam

✅ **Test your webcam/mic** - Use OnVUE's system check

✅ **Clear your workspace** - Remove prohibited items from your area

### After Your Exam

✅ **Restore services** - Run the script again and use Option 8

✅ **Restart if needed** - A full restart ensures everything returns to normal

---

## 🔧 Troubleshooting

### Script Won't Run

**Error: "Execution of scripts is disabled on this system"**

Solution:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Some Operations Fail

**Issue: Services won't stop or processes won't close**

Solutions:
- Run PowerShell as Administrator
- Close applications manually first
- Restart your computer and try again

### Applications Restart Automatically

**Issue: Processes reappear after being closed**

Solutions:
- Stop the related services (Option 4)
- Disable the application from starting automatically (Task Manager → Startup)
- Uninstall aggressive applications temporarily

### High-Risk Software Won't Close

**Issue: Virtual machines or screen recorders persist**

Solutions:
- Close them through their own interface first
- Stop their services (Option 4)
- Restart your computer
- Temporarily uninstall if necessary

### After Exam: Services Won't Restore

**Issue: Option 8 doesn't restart services**

Solutions:
- Restart your computer (services will auto-start)
- Manually start services through Services.msc
- Check if services are set to "Disabled" in Services.msc

---

## 🤝 Contributing

Contributions are welcome! Here's how you can help:

### Reporting Issues

If you encounter problems:
1. Open an issue on GitHub
2. Include your Windows version
3. Describe what happened vs. what you expected
4. Include any error messages (screenshot or copy/paste)

### Suggesting Improvements

Have ideas for new features?
1. Open an issue with the "enhancement" label
2. Describe the feature and why it would be helpful
3. Provide examples if possible

### Submitting Pull Requests

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

### Code Standards

- Follow PowerShell best practices
- Use approved verbs for functions (Get, Set, Test, Start, Stop, etc.)
- Add comments for complex logic
- Test thoroughly before submitting

---

## ⚠️ Disclaimer

**This script is provided as-is, without warranty of any kind.**

- This is an **unofficial** tool and is **not affiliated with, endorsed by, or connected to Pearson VUE** in any way
- The author is not responsible for any issues arising from use of this script
- **Always follow official Pearson VUE guidelines** for system preparation
- **Test this script before your actual exam** to ensure it works correctly on your system
- **Backup important data** before running system preparation scripts
- Some legitimate system processes may be closed; use at your own discretion
- The script does not guarantee exam success or that OnVUE will function properly

**Important Notes:**
- Stopping services and closing processes can affect system functionality
- Always save your work before running this script
- Some applications may not function properly until services are restored or system is restarted
- This script is intended for use on personal computers only

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

```
MIT License

Copyright (c) 2025

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## 🙏 Acknowledgments

- Inspired by the common struggles of test-takers dealing with OnVUE technical issues
- Thanks to the PowerShell community for best practices and guidance
- Built with the goal of reducing exam-day stress for students and professionals

---

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/ChrisMunnPS/onvue-system-preperation/issues)
- **Discussions**: [GitHub Discussions](https://github.com/ChrisMunnPS/onvue-system-preperation/discussions)
- **Official OnVUE Support**: [Pearson VUE Support](https://home.pearsonvue.com/onvue)

---

## ⭐ Star This Repository

If this script helped you, please consider giving it a star! It helps others discover the tool.

---

**Good luck on your exam! 🍀**
