# Install NodeJS Using NVM

To install and manage multiple Node.js versions on **Ubuntu**, we can use **Node Version Manager (NVM)**. NVM allows us to install multiple versions of Node.js and switch between them easily.

## 1. Install NVM

First, download and install NVM using the command line.

Open a terminal and run the following command to download and install **NVM**:

```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash
```

After installation, load NVM into current shell session by running:

```bash
source ~/.bashrc
```

Verify the installation by running:

```bash
nvm --version
```

## 2. Install Node.js Versions

With NVM installed, we can now install different versions of Node.js.

To install a specific version of Node.js (for example, **version 16**):

```bash
nvm install 16
```

You can also install the latest version:

```bash
nvm install node
```

## 3. List Installed Node.js Versions

To see all the Node.js versions installed on your system, run:

```bash
nvm ls
```

## 4. Switch Between Node.js Versions

To use a different version of Node.js, use the nvm use command. For example, to switch to version 16:

```bash
nvm use 16
```

To set a default version globally for all new terminal sessions:

```bash
nvm alias default 16
```

## 5. Verify the Active Node.js Version

We can verify which version of Node.js is currently active by running:

```bash
node -v
```

## 6. Uninstall a Node.js Version

To uninstall a specific version of Node.js:

```bash
nvm uninstall 16
```

**This setup should allow us to easily manage multiple versions of Node.js**
