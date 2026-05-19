# Steghide Documentation

## Steghide

`steghide` is a steganography tool used to hide secret data inside image or audio files without visibly changing the file.

It supports embedding data into:

- JPEG images
- BMP images
- WAV audio files
- AU audio files

Common use cases:

- Hide confidential text inside images
- Securely transfer hidden messages
- Practice cybersecurity and steganography techniques

Official project:

https://steghide.sourceforge.net/

## Install Steghide

#### Install on RHEL / CentOS / Fedora

```bash
sudo dnf install steghide
```

#### Verify

```bash
steghide --version
```

## Embed Secret Data into an Image

#### Create a Secret File

```bash
echo "This is secret data" > secret.txt
```

#### Embed Data

```bash
steghide embed -ef secret.txt -cf linux.jpg
```

or

```bash
steghide embed --embedfile secret.txt --coverfile linux.jpg
```

After running the command, Steghide asks for a **passphrase**

## Extract Hidden Data

#### Extract Data

```bash
steghide extract -sf linux.jpg
```

or 

```bash
steghide extract --stegofile linux.jpg
```

You will be prompted for the **passphrase** used during embedding.

## Useful Commands

#### Show File Information

```bash
steghide info linux.jpg
```

#### Extract Without Prompt

```bash
steghide extract -sf linux.jpg -p mypassword
```

#### Embed Without Compression

```bash
steghide embed -ef secret.txt -cf linux.jpg -Z
```

## Security Notes

- Always use a strong passphrase
- Hidden data can still be detected using **forensic tools**
- JPEG images are commonly used for steganography
- Do not reuse publicly shared images for sensitive data


## Supported File Formats

| Type | Formats |
|---|---|
| Images | JPEG, BMP |
| Audio | WAV, AU |

