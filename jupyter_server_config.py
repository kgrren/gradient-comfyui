# Paperspace uses Jupyter as the externally reachable entry point. The generic
# jupyter-server-proxy route remains available at /proxy/8188/ after ComfyUI is
# started with `start-comfyui`.

c.ServerApp.allow_origin = "*"
c.ServerApp.allow_remote_access = True
c.ServerApp.trust_xheaders = True
c.ServerApp.tornado_settings = {
    "headers": {
        "Content-Security-Policy": "frame-ancestors 'self' *",
    }
}

# Optional named launcher. It starts the same persistent /notebooks/comfyui
# checkout and proxies it under /comfyui/. If you already use /proxy/8188/, you
# can keep doing so; this is only an additional convenience entry.
c.ServerProxy.servers = {
    "comfyui": {
        "command": ["/usr/local/bin/start-comfyui"],
        "port": 8188,
        "absolute_url": False,
        "timeout": 120,
        "launcher_entry": {
            "enabled": True,
            "title": "ComfyUI",
        },
    }
}
