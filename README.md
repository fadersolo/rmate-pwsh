# rmate-pwsh

A native PowerShell implementation of the `rmate` protocol. 

`rmate-pwsh` allows you to edit files on a remote server (Windows or Linux) using your local text editor (like VS Code, Sublime Text, or TextMate) over an SSH session.

## 🚀 Features

* **Zero Dependencies:** Pure PowerShell implementation.
* **Cross-Platform:** Works on Windows PowerShell 5.1 and PowerShell Core (6.0+).
* **Lightweight:** A single script that handles the `rmate` protocol seamlessly.

## 🛠 Installation

### Option 1: Manual Download
Download the `rmate.ps1` script and add it to your `PATH`.

```powershell
# Example: Download to a Scripts folder
Invoke-WebRequest -Uri "[https://raw.githubusercontent.com/fadersolo/rmate-pwsh/main/rmate.ps1](https://raw.githubusercontent.com/fadersolo/rmate-pwsh/main/rmate.ps1)" -OutFile "$HOME\Documents\rmate.ps1"