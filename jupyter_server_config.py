# jupyter_server_config.py
c.ServerProxy.servers = {
    'comfyui': {
        'command': ['echo', 'ComfyUI should be started from Notebook'],
        'port': 8188,
        'absolute_url': False,
        'timeout': 60,
        'launcher_entry': {
            'enabled': True,
            'title': 'ComfyUI',
            # ComfyUIのアイコンがあれば指定可能ですが、ここでは省略
        }
    }
}

# iframe内での表示やCORS関連の許可
c.ServerApp.allow_origin = '*'
c.ServerApp.tornado_settings = {
    'headers': {
        'Content-Security-Policy': "frame-ancestors 'self' *"
    }
}
