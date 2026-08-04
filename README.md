# Homelab SmartCheck API

## Overview

A small FastAPI microservice that reads SMART disk health logs and exposes the parsed data through an API.

The SMART check itself is managed separately by the [Homelab-Config SmartCheck](https://github.com/Pica-Eduard-Ionut/Homelab-Config/tree/main/server/scripts/smartcheck/README.md) configuration.

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
├── app.py
├── requirements.txt
├── Containerfile
├── compose.yaml
└── README.md
```

* `app.py` - FastAPI application that reads and parses the SMART log files.
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
