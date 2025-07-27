from http.server import BaseHTTPRequestHandler
import json

class handler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.end_headers()
        
        if self.path == '/':
            response = {"message": "Word2Vec Association API", "status": "running"}
        elif self.path == '/api/v1/health':
            response = {"status": "healthy", "message": "API is running"}
        else:
            response = {"error": "Not found"}
            
        self.wfile.write(json.dumps(response).encode())
        return