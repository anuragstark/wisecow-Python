import random
from flask import Flask, Response, jsonify
import cowsay
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
import time

app = Flask(__name__)

# Prometheus Metrics
REQUEST_COUNT = Counter('wisecow_requests_total', 'Total number of requests', ['method', 'endpoint'])
REQUEST_LATENCY = Histogram('wisecow_request_latency_seconds', 'Request latency in seconds', ['method', 'endpoint'])

QUOTES = [
    "It works on my machine.",
    "Have you tried turning it off and on again?",
    "A computer lets you make more mistakes faster than any invention in human history.",
    "To err is human, but to really foul things up you need a computer.",
    "There are only two hard things in Computer Science: cache invalidation and naming things.",
    "99 little bugs in the code. 99 little bugs in the code. Take one down, patch it around. 127 little bugs in the code...",
    "I'm not a great programmer; I'm just a good programmer with great habits.",
    "First, solve the problem. Then, write the code."
]

@app.before_request
def before_request():
    app.config['START_TIME'] = time.time()

@app.after_request
def after_request(response):
    from flask import request
    latency = time.time() - app.config.get('START_TIME', time.time())
    REQUEST_COUNT.labels(method=request.method, endpoint=request.path).inc()
    REQUEST_LATENCY.labels(method=request.method, endpoint=request.path).observe(latency)
    return response

@app.route('/')
def cow():
    quote = random.choice(QUOTES)
    cow_output = cowsay.get_output_string('cow', quote)
    # Wrap in <pre> tags to preserve ASCII art formatting when viewed in a browser
    html = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <title>Wisecow</title>
        <style>
            body {{
                background-color: #1e1e1e;
                color: #00ff00;
                font-family: monospace;
                padding: 2rem;
                display: flex;
                justify-content: center;
                align-items: center;
                height: 100vh;
                margin: 0;
            }}
            pre {{
                font-size: 1.2rem;
            }}
        </style>
    </head>
    <body>
        <pre>{cow_output}</pre>
    </body>
    </html>
    """
    return html

@app.route('/health')
def health():
    return jsonify({"status": "healthy"}), 200

@app.route('/metrics')
def metrics():
    return Response(generate_latest(), mimetype=CONTENT_TYPE_LATEST)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=4499)
