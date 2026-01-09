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
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/fadersolo/rmate-pwsh/main/rmate.ps1" -OutFile "$HOME\Documents\rmate.ps1"
```

### Option 2: Clone the Repo

```PowerShell
git clone https://github.com/fadersolo/rmate-pwsh.git
```


## 📖 How to Use

### 1. Prepare your Local Editor
Ensure your local editor has the necessary "Remote Server" extension installed:

VS Code: Install the Remote VSCode extension and start the server.

Sublime Text: Install the rsub package.

### 2. Connect via SSH with a Reverse Tunnel
To allow the remote server to talk back to your local editor, you must open a reverse tunnel (default port is 52698).

```Bash
ssh -R 52698:localhost:52698 user@remote-host
```

### 3. Open a File
Once connected to the remote server, run the script:

```PowerShell
./rmate.ps1 my_script.ps1
The file will instantly pop up in your local editor. When you save the file locally, the changes are automatically pushed back to the remote server.
```


## ⚙️ Configuration

```
Parameter	Default	Description
-Port	    52698	    The port the local editor is listening on.
-Host	    localhost	The host address (usually localhost via tunnel).
-Wait	    True	    Wait for the editor to close before returning control.
```

## 🤝 Contributing
Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License
This project is licensed under the MIT License.
