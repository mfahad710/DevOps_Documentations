# Convert `.deb` Packages to `.rpm` Using Alien

## Overview

`Alien` is a package conversion tool that allows you to convert Linux package formats between:

- `.deb` (Debian/Ubuntu)
- `.rpm` (RHEL/CentOS/Rocky/AlmaLinux/Fedora)

## Install Alien

#### RHEL / CentOS / Fedora

```bash
sudo dnf install alien -y
```

## Convert `.deb` to `.rpm`

#### Basic Syntax

```bash
sudo alien -r package-name.deb
```

#### Example

```bash
sudo alien -r cursor_3.3.30_amd64.deb
```

Generated output:

```bash
cursor-3.3.30-2.x86_64.rpm
```

## Install the Generated RPM Package

#### Using RPM

```bash
sudo rpm -ivh cursor-3.3.30-2.x86_64.rpm
```

## Useful Alien Options

| Option | Description |
|---|---|
| `-r` | Convert to RPM |
| `-d` | Convert to DEB |
| `-k` | Keep original version number |
| `-v` | Verbose output |
| `--scripts` | Include package scripts |

#### Example with Scripts

```bash
sudo alien -r --scripts app.deb
```

## Verify RPM Package

#### Show Package Information

```bash
rpm -qip package.rpm
```

#### List Package Contents

```bash
rpm -qlp package.rpm
```

## Common Issues

#### 1. Dependency Problems

Alien only converts the package format.  
It does not automatically fix dependency compatibility between Debian and RHEL-based systems.  
You may need to manually install dependencies:

```bash
sudo dnf install <dependency-name>
```

#### 2. Service Script Compatibility

Some Debian service scripts may not work correctly on RPM-based systems.

Use:

```bash
sudo alien -r --scripts package.deb
```

Then test the application carefully.

## Best Practices

Whenever possible, prefer:

- Native RPM packages
- Official repositories
- Building software from source

Converted packages may sometimes cause:

- Dependency conflicts
- Service startup issues
- Library compatibility problems

## Official Reference

[Alien Official Website](https://joeyh.name/code/alien/)

