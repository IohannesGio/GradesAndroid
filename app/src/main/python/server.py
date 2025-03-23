'''Server in python using flask'''
import json
from flask import Flask, render_template, request, jsonify, url_for, abort # module for the server
import database


app = Flask(__name__) # setting the server files


@app.errorhandler(404)
def return_404(error):
    '''generic return 404 error'''
    return render_template("404.html"), 404


@app.route("/editGrade", methods=['POST'])
def edit_grade():
    '''post method to edit a grade'''
    grade_data = request.get_json()
    edit_status = database.edit_grade(grade_data)
    if edit_status:
        return jsonify({'ok': True, 'message': 'grade modified'}), 200
    return jsonify({'ok': False, 'message': 'grade not modified, try again'}), 400

@app.route("/subject/<subject>", methods=['GET'])
def return_subject_page(subject):
    '''return subject page'''
    if subject in [x[0] for x in database.list_subjects()]:
        periods = database.get_periods()
        average = database.return_average_by_period_bis(subject)
        average_first_period = database.return_average_by_period(subject, periods[0][0], periods[0][1])
        delta = 'N/A' if average == 'N/A' or average_first_period == "N/A" else round(float(average) - float(average_first_period), 2)
        return render_template("subject.html", subject=subject, grades=database.list_grades(subject), average=float(average) if average.isdigit() is True else average, objective=database.return_objective(subject), achievement = database.objective_achievement_subject_by_period(subject), average_first_period = float(average_first_period) if average_first_period.isdigit() else average_first_period, delta = delta), 200
    abort(404)


@app.route("/addGrade", methods=['POST'])
def add_grade():
    '''adds a grade received from the web page'''
    grade_data = request.get_json()
    response = database.add_grade(grade=grade_data['grade'], subject_name=grade_data['subject'], date=grade_data['date'],weight=grade_data['grade_weight'], type_=grade_data['type'])
    if response:
        return jsonify({'ok':True, 'message': 'grade added successfully'}), 200
    return jsonify({'ok':False, 'message': 'error while adding a grade'}), 400


@app.route("/deleteGrade", methods=['POST'])
def delete_grade():
    '''deletes a grade given an input from the web page'''
    grade_data = request.get_json()
    response = database.delete_grade(id_=grade_data['id'])
    if response:
        return jsonify({'ok':True, 'message': 'grade deleted successfully'}), 201
    return jsonify({'ok':False, 'message': 'error while deleting a grade'}), 400


@app.route("/", methods=["GET"])
def return_index():
    '''return home page'''
    return render_template("index.html"), 200


@app.route("/index-content", methods=['GET'])
def return_content():
    '''return home page content'''
    general_average_rounded=database.return_average_by_date_period()
    safe_value = round(general_average_rounded[1][-1]['average_grade'], 2) if general_average_rounded[1] and len(general_average_rounded[1]) > 0 else 'N/A'
    return render_template("index-content.html", averages_list=database.return_averages_by_period(), subjects_list = database.list_subjects(), general_average=database.return_general_average_by_period(), safe_value=safe_value, average_objective = database.return_average_objective()), 200

@app.route("/addSubject", methods=['POST'])
def add_subject():
    '''adds a subject given by the web page'''
    subject: json = request.get_json()
    response = database.add_subject(subject['subject'])
    if response is True:
        return jsonify({'ok':True, 'message': 'subject added successfully'}), 201
    if response == "duplicate subject":
        return jsonify({'ok':False, 'message': 'the subject already exists'}), 400
    return jsonify({'ok':False, 'message': 'errors while adding a subject'}), 400


@app.route("/redirect", methods=['POST'])
def redirect():
    '''redirects to the subject page'''
    subject: json = request.get_json()
    subject_redirect = subject['subject_redirect']
    return jsonify({'redirect': url_for('return_subject_page', subject=subject_redirect)}), 200


@app.route("/getAverageByDate", methods=['GET'])
def get_average_by_date():
    '''get request to return the average by date'''
    data_fp, data_rounded_fp = database.return_average_by_date("first")
    data_sp, data_rounded_sp = database.return_average_by_date("second")
    return jsonify({'data_fp': data_fp, 'data_rounded_fp': data_rounded_fp, 'data_sp': data_sp, 'data_rounded_sp': data_rounded_sp}), 200


@app.route("/stats", methods=['GET'])
def render_charts():
    '''redirects to stats page'''
    _, number, subject_number = database.objective_achievement_by_period()
    return render_template("stats.html", grade_bar_fp=json.dumps(database.return_grade_proportions_by_period("first")), grade_bar_sp=json.dumps(database.return_grade_proportions_by_period("second")), subject_number = subject_number, number = number), 200


@app.route("/settings", methods=['GET'])
def redirect_settings():
    '''redirects to settings page'''
    return render_template("settings.html", subjects = database.list_subjects(), periods = database.get_periods()), 200


@app.route("/deleteSubject", methods=['POST'])
def delete_subject():
    '''deletes a subject given by the web page'''
    subject: json = request.get_json()
    response = database.delete_subject(subject['subject_to_delete'])
    if response:
        return jsonify({'ok':True, 'message': 'subject deleted successfully'}), 201
    return jsonify({'ok':False, 'message': 'error while deleting a subject'}), 400


@app.route("/renameSubject", methods=['POST'])
def rename_subject():
    '''renames a subject given by the web page'''
    subject: json = request.get_json()
    response = database.rename_subject(subject['subject_to_rename'], subject['new_name'])
    if response is True:
        return jsonify({'ok':True, 'message': 'subject renamed successfully'}), 201
    if response == "duplicate subject":
        return jsonify({'ok':False, 'message': 'the subject already exists'}), 400
    return jsonify({'ok':False, 'message': 'error while renaming a subject'}), 400


@app.route("/setObjective", methods=['POST'])
def set_objective():
    '''sets an objective given by the web page'''
    objective: json = request.get_json()
    response = database.set_objective(objective['subject'], objective['objective'])
    if response:
        return jsonify({'ok':True, 'message': 'objective set successfully'}), 201
    return jsonify({'ok':False, 'message': 'error while setting an objective'}), 400


@app.route("/setPeriod", methods=['POST'])
def set_period():
    '''sets a period given by the web page'''
    period: json = request.get_json()
    response = database.set_period(period['period'], period['start'], period['end'])
    if response is True:
        return jsonify({'ok':True, 'message': 'period set successfully'}), 201
    if response == "invalid dates":
        return jsonify({'ok':False, 'message': 'invalid dates'}), 400
    return jsonify({'ok':False, 'message': 'error while setting a period'}), 400


@app.route("/changePeriod", methods=['GET', 'POST'])
def change_period():
    '''changes the period given by the web page'''
    if request.method == 'POST':
        period: json = request.get_json()
        subject = period.get('subject')
        selected_period = period.get('period')
    else:
        subject = request.args.get('subject')
        selected_period = request.args.get('period')

    periods = database.get_periods()
    if selected_period == 'all':
        return render_template("subject-content.html", grades=database.list_grades_by_period(subject, periods[0][0], periods[1][1])), 200
    if selected_period == 'first':
        return render_template("subject-content.html", grades=database.list_grades_by_period(subject, periods[0][0], periods[0][1])), 200
    if selected_period == 'second':
        return render_template("subject-content.html", grades=database.list_grades_by_period(subject, periods[1][0], periods[1][1])), 200
    abort(404)


def main():
    app.run(debug=False, host="127.0.0.1", port=5000)
