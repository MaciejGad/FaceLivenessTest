import base64
from flask import Flask, json, jsonify, request
import boto3
import uuid
import traceback
import os
from functools import wraps
import datetime
import sys

USERNAME = os.getenv("FACE_AUTH_USER")
PASSWORD = os.getenv("FACE_AUTH_PASS")

if not USERNAME or not PASSWORD:
    raise EnvironmentError("FACE_AUTH_USER and FACE_AUTH_PASS environment variables must be set")

app = Flask(__name__)

AWS_REGION = "eu-west-1"  # Ensure you have a region that supports face liveness
rekognition_client = boto3.client("rekognition", region_name=AWS_REGION)

def check_auth(username, password):
    return username == USERNAME and password == PASSWORD

def authenticate():
    return jsonify({"error": "Unauthorized"}), 401

def requires_auth(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        auth = request.authorization
        if not auth:
            username = request.cookies.get('username')
            password = request.cookies.get('password')
            if username and password and check_auth(username, password):
                return f(*args, **kwargs)
        auth = request.authorization
        if not auth or not check_auth(auth.username, auth.password):
            return authenticate()
        return f(*args, **kwargs)
    return decorated

@app.route('/create_liveness_session', methods=['GET'])
@requires_auth
def create_liveness_session():
    client_request_token = str(uuid.uuid4())

    try:
        response = rekognition_client.create_face_liveness_session(
            ClientRequestToken=client_request_token
        )
        session_id = response['SessionId']
        return jsonify({"session_id": session_id})
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route('/get_liveness_result/<session_id>', methods=['GET'])
@requires_auth
def get_liveness_result(session_id):
    try:
        json_path = f"files/{session_id}.json"
        if os.path.exists(json_path):
            with open(json_path, 'r') as f:
                data = f.read()
            print(f"Returning cached data for session {session_id}")
            return data
        response = rekognition_client.get_face_liveness_session_results(
            SessionId=session_id
        )
        print(response)
        status = response["Status"]
        if status == "SUCCEEDED":
            session_id = response["SessionId"]
            if "ReferenceImage" in response:
                image_bytes = response["ReferenceImage"]["Bytes"]
                with open(f"files/{session_id}.jpg", 'wb') as f:
                    f.write(image_bytes)
            output = jsonify({"status": response["Status"], "confidence": response["Confidence"], "session_id": session_id, "response_metadata": response["ResponseMetadata"]})
            with open(f"files/{session_id}.json", 'w') as f:
                f.write(output.get_data(as_text=True))
            return output
        else:
            return jsonify({"status": response["Status"]})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/image/<session_id>', methods=['GET'])
def show_image(session_id):
    try:
        image_path = f"files/{session_id}.jpg"
        with open(image_path, 'rb') as f:
            image_data = f.read()
        return app.response_class(image_data, mimetype='image/jpeg')
    except FileNotFoundError:
        return jsonify({"error": "Image not found"}), 404
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/details/<session_id>', methods=['GET'])
@requires_auth
def display_details(session_id):
    try:
        json_path = f"files/{session_id}.json"
        image_path = f"files/{session_id}.jpg"
        
        with open(json_path, 'r') as f:
            data = f.read()
        
        details = json.loads(data)
        image_base64 = None
        if os.path.exists(image_path):
            with open(image_path, 'rb') as f:
                image_data = f.read()
            image_base64 = base64.b64encode(image_data).decode('utf-8')

        with open('templates/details.html', 'r') as f:
                html_content = f.read()
        html_content = html_content.replace("{% session_id %}", details["session_id"])
        html_content = html_content.replace("{% status %}", details["status"])
        html_content = html_content.replace("{% confidence %}", str(details["confidence"]))
        html_content = html_content.replace("{% response_metadata %}", str(details["response_metadata"]))
        if image_base64:
            html_content = html_content.replace("{% image_base64 %}", image_base64)
        return html_content
    except FileNotFoundError:
        return jsonify({"error": "Details not found"}), 404
    except Exception as e:
        traceback.print_exc()
        print(f"An error occurred: {e}")
        return jsonify({"error": str(e)}), 500

@app.route('/', methods=['GET'])
@requires_auth
def list_sessions():
    try:
        sessions = [
            {
            "session_id": f.replace('.json', ''),
            "creation_date": os.path.getctime(os.path.join('files', f))
            }
            for f in os.listdir('files') if f.endswith('.json')
        ]
        sessions.sort(key=lambda x: x["creation_date"], reverse=True)
        list = "<ul>"
        for session in sessions:
            session_id = session["session_id"]
            creation_date = datetime.datetime.fromtimestamp(session["creation_date"]).strftime('%Y-%m-%d %H:%M:%S')
            list += f"<li class=\"list-group-item\">{creation_date} <a href=\"/details/{session_id}\">{session_id}</a></li>"
        list += "</ul>"
        with open('templates/index.html', 'r') as f:
                html_content = f.read()
        html_content = html_content.replace("{% file_list %}", list)
        return html_content
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        username = request.form['username']
        password = request.form['password']
        if check_auth(username, password):
            response = jsonify({"message": "Login successful"})
            response.set_cookie('username', username)
            response.set_cookie('password', password)
            return response
        else:
            return jsonify({"error": "Invalid credentials"}), 401
    else:
        try:
            with open('templates/login.html', 'r') as f:
                login_form = f.read()
            return login_form
        except FileNotFoundError:
            return jsonify({"error": "Login template not found"}), 404

if __name__ == '__main__':
    if '--local' in sys.argv:
        # os.environ['AWS_ACCESS_KEY_ID'] = 'your-local-access-key-id'
        # os.environ['AWS_SECRET_ACCESS_KEY'] = 'your-local-secret-access-key'
        app.run(host="192.168.68.120", debug=True)
    else:
        app.run()
