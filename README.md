# Homelab SmartCheck API

## Overview

A lightweight, high-performance microservice built with the **Drogua (Lua)** framework that reads SMART disk health logs and exposes the parsed data through a REST API. 

The SMART check itself is managed separately by the [Homelab-Config SmartCheck](https://github.com/Pica-Eduard-Ionut/Homelab-Config/tree/main/server/scripts/smartcheck/README.md) configuration.

(There is also a FastAPI version in the folder `python` that I used previously)

## API

Get SMART logs:
```text
GET /logs
```

Limit the number of results:
```text
GET /logs?limit=7
```

FastAPI documentation:
```text
/docs
```

The API runs on port `8000`.

## Project Structure

```text
.
├── app.lua
├── compose.yaml
├── Containerfile
├── drogua
├── lib
├── LICENSE
├── Python
└── README.md
```
* `app.lua` - Drogua application that reads, parses, and serves the SMART log files asynchronously.
* `config.json` - Drogua framework configuration (logging, threading, etc.).
* `drogua` - Drogua framework executable for building the docker.
* `lib` - Runtime dependencies for the drogua executable that are added to the docker.
* `Python` - Alternative FastAPI application that reads and parses the SMART log files.
* `requirements.txt` - Python dependencies for the application.
* `Containerfile` - Defines the container image for the API.
* `compose.yaml` - Defines the container, port mapping, volume, and restart policy.
* `README.md` - Project documentation.

## Container Volume

The SMART logs are generated on the host by the SMART check configuration and stored in:
```text
/opt/homelab_smartcheck/logs
```

The directory is mounted into the container at:
```text
/app/logs
```

The volume is mounted as read-only since the API only needs to read the generated logs.
```yaml
volumes:
  - /opt/homelab_smartcheck/logs:/app/logs:ro
```

## Run

Build and start the container:
```bash
podman compose build
podman compose up -d
```

Stop the container:
```bash
podman compose down
```

View container logs:
```bash
podman compose logs -f
```

## SELinux

The homelab server runs Fedora Server with SELinux enabled.

The SMART log directory must have a SELinux context that allows the container to read the files.

The expected context is:
```text
container_file_t
```

Check the directory context:
```bash
ls -Zd /opt/homelab_smartcheck/logs
```

Check the individual files:
```bash
ls -Z /opt/homelab_smartcheck/logs
```

If required, apply the context with:
```bash
sudo chcon -R -t container_file_t /opt/homelab_smartcheck/logs
```
