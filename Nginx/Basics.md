# NGINX Basics

## Topics
1. Static web page (basic `server` + `root`)
2. MIME types (serve correct `Content-Type` headers)
3. `location` blocks (prefix, regex, `root` vs `alias`, `try_files`)
4. Redirect + rewrite (`return` and `rewrite`)
5. Load balancing (`upstream` + `proxy_pass`)


## Prerequisites

- NGINX installed
- Ability to bind to port `8080`
- Content folders referenced by the configs:
  - `/var/www/html` (for the “static site” examples)
  - `/var/www/wordpress` (for the `wordpress`/`cabs` examples)

## 1) Static Web Page

#### nginx.conf
```nginx
http {
    server{
        listen 8080;
        root /var/www/html
    }
}

events {}
```

- The minimal building blocks:
  - `events {}`
  - `http { server { ... } }`
- Serving static files from a document root:
  - `listen 8080;`
  - `root /var/www/html;`



## 2) MIME Types

#### nginx.conf
```nginx
http {
    
    include mime.types;

    server{
        listen 8080;
        root /var/www/html
    }
}

events {}
```

- `include mime.types;` loads a `types { ... }` mapping.
- When we serve `file.css`, `file.js`, `file.png`, etc., NGINX can set a correct `Content-Type` response header.

Without proper MIME type mapping, browsers may:

- Refuse to execute scripts
- Render CSS incorrectly
- Download assets instead of displaying them

We should see a `Content-Type: text/css` header when MIME types are included.

## 3) Location Blocks

#### nginx.conf
```nginx
http {
    
    include mime.types;

    server{
        listen 8080;
        root /var/www/html;

        # Regular Expresion
        location ~* /count/[0-9] {
            root /var/www/html;
            try_files /index.html =404;
        }

        location /wordpress {
            root /var/www;
        }

        location /cabs{
            alias /var/www/wordpress;
        }

        location /vegetables{
            root /var/www;
            try_files /vegetables/veggies.html /index.html =404;
        }
    }
}

events {}
```

#### (A) Regex `location` + `try_files`

```nginx
location ~* /count/[0-9] {
    try_files /index.html =404;
}
```

- `~*` means **case-insensitive regex** matching.
- `try_files` checks files in order and returns `404` if none exist.
- With `root /var/www/html;` in the `server`, `try_files /index.html` resolves to `/var/www/html/index.html`.

#### (B) Prefix `location` + `root`

```nginx
location /wordpress {
    root /var/www;
}
```

With `root`, NGINX builds the path as:

- filesystem path = `root` + URI
- `/wordpress/...` becomes `/var/www/wordpress/...`

#### (C) Prefix `location` + `alias`

```nginx
location /cabs {
    alias /var/www/wordpress;
}
```

With `alias`, NGINX replaces the matching location prefix:

- `/cabs/...` becomes `/var/www/wordpress/...`

Rule of thumb:

- Use `root` when you want *filesystem = root + full URI*.
- Use `alias` when you want to *map a URI prefix to a different directory*.

#### (D) `try_files` fallback chain

```nginx
location /vegetables {
    root /var/www;
    try_files /vegetables/veggies.html /index.html =404;
}
```

- If `/var/www/vegetables/veggies.html` exists, serve it.
- Else if `/var/www/index.html` exists, serve it.
- Else return `404`.

## 4) Redirect and Rewrite

#### nginx.conf
```nginx
http {
    
    include mime.types;

    server{
        listen 8080;
        root /var/www/html;


        rewrite ^/number/(\w+) /count$1;

        # Regular Expresion
        location ~* /count/[0-9] {
            root /var/www/html;
            try_files /index.html =404;
        }

        location /wordpress {
            root /var/www;
        }

        location /cabs{
            alias /var/www/wordpress;
        }

        location /vegetables{
            root /var/www;
            try_files /vegetables/veggies.html /index.html =404;
        }

# whenever request hits the /crops then it redirect to the /wordpress
        location /crops {
            return 307 /wordpress;
        }
    }
}

events {}
```

#### Rewrite

Current rule:

```nginx
rewrite ^/number/(\w+) /count$1;
```

- This rewrites requests like `/number/5` to `/count5`.
- But the regex `location` is written to match `/count/<digit>`.

A typical corrected rewrite to match `/count/<value>` is:

```nginx
rewrite ^/number/(\w+)$ /count/$1 last;
```

Notes:

- `last` restarts location matching with the new URI.
- Adding the `$` ensures the whole URI is matched.

#### Redirect

```nginx
location /crops {
    return 307 /wordpress;
}
```

- `return 307` sends a real HTTP redirect to the client.
- `307 Temporary Redirect` keeps the HTTP method (useful for POST/PUT scenarios).


## 5) Load Balancing

#### nginx.conf
```nginx
http {
    
    include mime.types;

    upstream backendservers {
        server 127.0.0.1:1111;
        server 127.0.0.1:2222;
        server 127.0.0.1:3333;
        server 127.0.0.1:4444;
    }

    server{
        listen 8080;
        root /var/www/html;

        location / {
            proxy_pass http://backendservers/
        }

        rewrite ^/number/(\w+) /count$1;

        # Regular Expresion
        location ~* /count/[0-9] {
            root /var/www/html;
            try_files /index.html =404;
        }

        location /wordpress {
            root /var/www;
        }

        location /cabs{
            alias /var/www/wordpress;
        }

        location /vegetables{
            root /var/www;
            try_files /vegetables/veggies.html /index.html =404;
        }

# whenever request hits the /crops then it redirect to the /wordpress
        location /crops {
            return 307 /wordpress;
        }
    }
}

events {}
```

- Defining an upstream pool:

```nginx
upstream backendservers {
    server 127.0.0.1:1111;
    server 127.0.0.1:2222;
    server 127.0.0.1:3333;
    server 127.0.0.1:4444;
}
```

- Proxying requests to that pool:

```nginx
location / {
    proxy_pass http://backendservers/;
}
```

By default, NGINX uses **round-robin** load balancing across the listed servers.
