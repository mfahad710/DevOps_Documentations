# NGINX

Nginx (pronounced "**engine-x**") is a high-performance, open-source software used for web serving, reverse proxying, caching, load balancing, and more. It's known for its stability, rich feature set, simple configuration, and low resource consumption.

## How Nginx Work

Traditional web servers (like old versions of **Apache**) use a threaded or process-driven architecture, where each simultaneous connection requires a separate thread or process. This can consume significant RAM and CPU when handling thousands of connections.

Nginx uses an asynchronous, event-driven architecture. Instead of creating a new process for each request, it handles multiple connections within a single worker process. Each worker process runs a tight event loop that can efficiently process thousands of connections.

### View of Operation:

- A master process reads the configuration file and manages the worker processes.
- Worker processes handle the actual incoming HTTP requests.
- Each worker processes requests asynchronously. When a request comes in, the worker processes it and moves on to the next one without waiting for the first to complete (e.g., waiting for a database response). Once the first request is ready to be finalized, the worker picks it back up.
- This non-blocking, event-driven model allows a single Nginx worker to handle a very large number of concurrent connections with minimal overhead.

## Example NGINX Files

**Reverse Proxy Base NGINX File**  

```nginx
server {
    listen 80;
    server_name api.fortrans.com;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;

    ssl_certificate /etc/ssl/fort/fort_plus_intermediateCA.crt;
    ssl_certificate_key /etc/ssl/fort/fort.key;

    # verify chain of trust of OCSP response using Root CA and Intermediate certs
    ssl_trusted_certificate /etc/ssl/fort/intermediateCA_rootCA_trustChain.crt;

    # Add the server name
    server_name api.fortrans.com;

    # Maximum allowed size of the client request body
    client_max_body_size 25M;

    location / {
        proxy_pass http://localhost:3011;
        proxy_connect_timeout 90s;
        proxy_send_timeout 90s;
        proxy_read_timeout 90s;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

**Explanation**   
- `return 301 https://$host$request_uri;`: This is the most important line. It instructs Nginx to respond to all HTTP requests with a **301 Permanent Redirect** to the exact same URL but using the `https://` protocol.
    - `$host` is a variable containing the original request's hostname (**api.fortrans.com**).
    - `$request_uri` is a variable containing the original URI (the part after the domain name, e.g., `/api/v1/users`).
- `proxy_connect_timeout`: Defines a timeout (90 seconds) for establishing a connection with the backend server.
- `proxy_send_timeout`: Defines a timeout (90 seconds) for sending a request to the backend server.
- `proxy_read_timeout`: Defines a timeout (90 seconds) for waiting for a response from the backend server. This is very important for preventing worker processes from getting stuck waiting on a slow app.
- `X-Real-IP $remote_addr`: Passes the real IP address of the client making the request.
- `X-Forwarded-For $proxy_add_x_forwarded_for`: Appends the client's IP address to the `X-Forwarded-For` header. This is the standard way to identify the originating IP of a client connecting through a proxy.
- `X-Forwarded-Proto $scheme`:Tells the backend application that the original request was made over https. This is essential if your application generates absolute URLs or needs to enforce HTTPS, as it would otherwise think the request was http.

---

**Serve Static Content**  
```nginx
server {
    listen 80;
    server_name stage.fortrans.com;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;

    ssl_certificate /etc/ssl/fort/fort_plus_intermediateCA.crt;
    ssl_certificate_key /etc/ssl/fort/fort.key;

    # verify chain of trust of OCSP response using Root CA and Intermediate certs
    ssl_trusted_certificate /etc/ssl/fort/intermediateCA_rootCA_trustChain.crt;

    # Add the server name
    server_name stage.fortrans.com;

    root /var/www/html/stage;
    index index.htm index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }
}
```

**Explanation**  

- `root /var/www/html/stage;`: This is the most important directive for this use case. It sets the **document root**, the base directory from which Nginx will serve static files. When a request is made for `https://stage.fortrans.com/about.html`, Nginx will look for the file at `/var/www/html/stage/about.html`.
- `index index.htm index.html;`: This directive defines the default files to serve when a client requests a directory (e.g., `https://stage.fortrans.com/`). Nginx will try to return `index.htm` first; if that file doesn't exist, it will then try to return `index.html`.
- `location /` block is configured completely differently from the API proxy. It uses the try_files directive, which is the standard way to serve SPAs.

- Here’s what `try_files $uri $uri/ /index.html;` does step-by-step for a request:
    - `$uri`: Nginx first tries to see if there is a static file that matches the requested URI. For example, a request for `/css/main.css` will check if the file `/var/www/html/stage/css/main.css` exists. If it does, Nginx serves it immediately. This is how your CSS, JS, images, and other assets are loaded.
    -  `$uri/`: If the first check fails (no file found), Nginx then checks to see if the request corresponds to a directory that exists. If it does, it will try to serve the `index` file (e.g., `index.html`) of that directory.
    - `/index.html`: If both previous checks fail (meaning there is no file and no directory that matches the request), Nginx will fall back to serving the `/index.html` file. This is the magic that enables client-side routing.