import os
from contextlib import contextmanager
from datetime import date

import pymysql
from flask import Flask, jsonify, request
from werkzeug.exceptions import HTTPException

app = Flask(__name__)

STATUSES = {"Not Started", "In Progress", "Submitted"}
FIELDS = ("course_code", "title", "description", "due_date", "status")


@contextmanager
def database_connection():
    connection = pymysql.connect(
        host=os.environ["DB_HOST"],
        port=int(os.environ.get("DB_PORT", "3306")),
        user=os.environ["DB_USER"],
        password=os.environ["DB_PASSWORD"],
        database=os.environ["DB_NAME"],
        charset="utf8mb4",
        cursorclass=pymysql.cursors.DictCursor,
        connect_timeout=5,
    )
    try:
        yield connection
    finally:
        connection.close()


def assignment_payload():
    payload = request.get_json()
    if not isinstance(payload, dict):
        return None, (jsonify(error="A JSON object is required."), 400)

    values = {}
    for field in FIELDS:
        value = payload.get(field)
        if not isinstance(value, str):
            return None, (jsonify(error=f"{field} must be a string."), 400)
        values[field] = value.strip()

    if not values["course_code"] or len(values["course_code"]) > 20:
        return None, (jsonify(error="course_code must contain 1 to 20 characters."), 400)
    if not values["title"] or len(values["title"]) > 150:
        return None, (jsonify(error="title must contain 1 to 150 characters."), 400)
    if len(values["description"]) > 2000:
        return None, (jsonify(error="description must not exceed 2000 characters."), 400)
    try:
        date.fromisoformat(values["due_date"])
    except ValueError:
        return None, (jsonify(error="due_date must be an ISO date (YYYY-MM-DD)."), 400)
    if values["status"] not in STATUSES:
        return None, (jsonify(error="status must be Not Started, In Progress, or Submitted."), 400)
    return values, None


@app.errorhandler(HTTPException)
def handle_http_error(error):
    return jsonify(error=error.description), error.code


@app.get("/api/health")
def health():
    return jsonify(status="ok")


@app.get("/api/instruments")
@app.get("/api/assignments")
def list_assignments():
    with database_connection() as connection:
        with connection.cursor() as cursor:
            cursor.execute(
                "SELECT id, course_code, title, description, due_date, status "
                "FROM assignments ORDER BY due_date, id"
            )
            assignments = cursor.fetchall()
    return jsonify(assignments)


@app.post("/api/instruments")
@app.post("/api/assignments")
def create_assignment():
    values, error = assignment_payload()
    if error:
        return error

    with database_connection() as connection:
        with connection.cursor() as cursor:
            cursor.execute(
                "INSERT INTO assignments (course_code, title, description, due_date, status) "
                "VALUES (%s, %s, %s, %s, %s)",
                tuple(values[field] for field in FIELDS),
            )
            assignment_id = cursor.lastrowid
        connection.commit()
    return jsonify(id=assignment_id, **values), 201


@app.get("/api/instruments/<int:assignment_id>")
@app.get("/api/assignments/<int:assignment_id>")
def get_assignment(assignment_id):
    with database_connection() as connection:
        with connection.cursor() as cursor:
            cursor.execute(
                "SELECT id, course_code, title, description, due_date, status "
                "FROM assignments WHERE id = %s",
                (assignment_id,),
            )
            assignment = cursor.fetchone()
    if assignment is None:
        return jsonify(error="Assignment not found."), 404
    return jsonify(assignment)


@app.put("/api/instruments/<int:assignment_id>")
@app.put("/api/assignments/<int:assignment_id>")
def update_assignment(assignment_id):
    values, error = assignment_payload()
    if error:
        return error

    with database_connection() as connection:
        with connection.cursor() as cursor:
            cursor.execute("SELECT id FROM assignments WHERE id = %s", (assignment_id,))
            if cursor.fetchone() is None:
                return jsonify(error="Assignment not found."), 404
            cursor.execute(
                "UPDATE assignments SET course_code = %s, title = %s, description = %s, "
                "due_date = %s, status = %s WHERE id = %s",
                tuple(values[field] for field in FIELDS) + (assignment_id,),
            )
        connection.commit()
    return jsonify(id=assignment_id, **values)


@app.delete("/api/instruments/<int:assignment_id>")
@app.delete("/api/assignments/<int:assignment_id>")
def delete_assignment(assignment_id):
    with database_connection() as connection:
        with connection.cursor() as cursor:
            cursor.execute("DELETE FROM assignments WHERE id = %s", (assignment_id,))
            deleted = cursor.rowcount
        connection.commit()
    if deleted == 0:
        return jsonify(error="Assignment not found."), 404
    return "", 204
