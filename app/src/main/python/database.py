'''Script that runs the operation on the database'''
from datetime import datetime
import sqlite3 # module to import to work with local databases

path = "/data/data/com.iohannes.grades/files/grades.sqlite3"

def round_custom(n):
    '''round a number to the next integer if its decimal part is 0.5 or more'''
    return int(n + 0.5)


def create_database(fun):
    '''Decorator to create the database if it doesn't exists'''
    def wrapper(*args, **kwargs):
        connection = sqlite3.connect(path)
        cursor = connection.cursor()
        command = """ CREATE TABLE IF NOT EXISTS subject_list (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            subject TEXT UNIQUE,
            objective REAL);""" # create the main table
        command_2 = """CREATE TABLE IF NOT EXISTS grades (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            subject_name TEXT,
            grade REAL,
            date INTEGER,
            weight REAL,
            type TEXT);""" # create the table where the grades are stored
        command_3 = """ CREATE TABLE IF NOT EXISTS settings (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            primary_colour TEXT); """
        command_4 = """ CREATE TABLE IF NOT EXISTS periods (
            name TEXT PRIMARY KEY,
            start_date INTEGER,
            end_date INTEGER); """
        command_5 = """INSERT OR IGNORE INTO periods (name, start_date, end_date) 
            VALUES 
            ('first_period', 'N/A', 'N/A'), 
            ('second_period', 'N/A', 'N/A')"""
        cursor.execute(command)
        cursor.execute(command_2)
        cursor.execute(command_3)
        cursor.execute(command_4)
        cursor.execute(command_5)
        connection.commit()
        connection.close()

        result = fun(*args, **kwargs)

        return result
    return wrapper


@create_database
def add_subject(subject: str):
    '''function to add a subject in the subject_list'''
    command = f"INSERT INTO subject_list (subject) VALUES ('{subject.upper()}');"
    try:
        connection = sqlite3.connect(path)
        cursor = connection.cursor()
        cursor.execute(command)
        connection.commit()
        return True
    except sqlite3.IntegrityError as e:
        print(e, command)
        return "duplicate subject"
    except Exception:
        return False
    finally:
        connection.close()


@create_database
def list_subjects() -> list:
    '''function to return all subjects added'''
    command = "SELECT * FROM subject_list"
    final_list = []
    try:
        connection = sqlite3.connect(path)
        cursor = connection.cursor()
        cursor.execute(command)
        for _,y,z in cursor:
            if not z:
                final_list.append((y, 'N/A'))
            else:
                final_list.append((y,z))
        connection.commit()
        return final_list
    except Exception as e:
        print(e)
        return final_list
    finally:
        connection.close()


@create_database
def return_objective(subject: str) -> str:
    '''function that returns the objective of a subject'''
    command = f"SELECT objective FROM subject_list WHERE subject = '{subject}'"
    try:
        connection = sqlite3.connect(path)
        cursor = connection.cursor()
        cursor.execute(command)
        objective = cursor.fetchone()
        return str(objective[0])
    except Exception as e:
        print(e)
        return 'N/A'
    finally:
        connection.close()


@create_database
def return_average_objective() -> str:
    '''function that returns the average objective of all subjects'''
    command = "SELECT ROUND(AVG(objective), 2) FROM subject_list;"
    try:
        connection = sqlite3.connect(path)
        cursor = connection.cursor()
        cursor.execute(command)
        objective = cursor.fetchone()
        return str(objective[0])
    except Exception as e:
        print(e)
        return 'N/A'
    finally:
        connection.close()


@create_database
def add_grade(subject_name, grade, date, weight, type_) -> bool:
    '''function that adds a grade'''
    command = f"INSERT INTO grades (subject_name, grade, date, weight, type) VALUES ('{subject_name}', '{grade}', '{date}', '{weight}', '{type_}')"
    try:
        connection = sqlite3.connect(path)
        cursor = connection.cursor()
        cursor.execute(command)
        connection.commit()
        return True
    except Exception as e:
        print(e, command)
        return False
    finally:
        connection.close()


@create_database
def list_grades(subject: str) -> list:
    '''function that returns a list of all the grades depending on the subject'''
    command = f"SELECT * FROM grades WHERE subject_name = '{subject}'"
    grades_list = []
    try:
        connection = sqlite3.connect(path)
        cursor = connection.cursor()
        cursor.execute(command)
        for b,_,x,y,z,a in cursor:
            grade_tuple = (b,x,y,z,a)
            grades_list.append(grade_tuple)
        connection.commit()
        return grades_list
    except Exception as e:
        print(e)
        return grades_list
    finally:
        connection.close()


@create_database
def list_grades_by_period(subject: str, start_date=None, end_date=None) -> list:
    '''function that returns a list of all the grades depending on the subject and optionally within a date range'''
    if start_date and end_date:
        command = f"SELECT * FROM grades WHERE subject_name = '{subject}' AND date BETWEEN '{start_date}' AND '{end_date}'"
    else:
        command = f"SELECT * FROM grades WHERE subject_name = '{subject}'"
    grades_list = []
    try:
        connection = sqlite3.connect(path)
        cursor = connection.cursor()
        cursor.execute(command)
        for b, _, x, y, z, a in cursor:
            grade_tuple = (b, x, y, z, a)
            grades_list.append(grade_tuple)
        connection.commit()
        return grades_list
    except Exception as e:
        print(e)
        return grades_list
    finally:
        connection.close()


@create_database
def list_all_grades() -> list:
    '''function that returns a list of all the grades'''
    command = "SELECT grade FROM grades;"
    grades_dict = []
    try:
        connection = sqlite3.connect(path)
        cursor = connection.cursor()
        cursor.execute(command)
        for grade in cursor:
            grades_dict.append(grade[0])
        return grades_dict
    except Exception as e:
        print(e)
        return grades_dict
    finally:
        connection.close()


@create_database
def return_grade_proportions() -> dict:
    '''function that returns how many times a grade appears, considering only the first digit'''
    base_list = list_all_grades()
    grade_proportions_dict = {}
    for x in range(11):
        grade_proportions_dict[x] = 0
    for grade in base_list:
        grade_proportions_dict[int(grade)] = grade_proportions_dict.get(int(grade), 0) + 1

    return grade_proportions_dict


@create_database
def return_grade_proportions_by_period(period: str) -> dict:
    '''function that returns how many times a grade appears in a period, considering only the first digit'''

    connection = sqlite3.connect(path)
    cursor = connection.cursor()

    cursor.execute("SELECT start_date, end_date FROM periods WHERE name = 'first_period'")
    first_period = cursor.fetchone()
    cursor.execute("SELECT start_date, end_date FROM periods WHERE name = 'second_period'")
    second_period = cursor.fetchone()

    if first_period[0] != 'N/A' and first_period[1] != 'N/A' and second_period[0] != 'N/A' and second_period[1] != 'N/A':
        start_date_fp, end_date_fp = first_period
        start_date_sp, end_date_sp = second_period
    else:
        connection.close()
        return {}

    command_fp = f"""
    SELECT grade 
    FROM grades 
    WHERE date BETWEEN '{start_date_fp}' AND '{end_date_fp}';
    """

    command_sp = f"""
    SELECT grade 
    FROM grades 
    WHERE date BETWEEN '{start_date_sp}' AND '{end_date_sp}';
    """

    grade_proportions_dict = {}
    for x in range(11):
        grade_proportions_dict[x] = 0

    try:
        if period == "first":
            cursor.execute(command_fp)
        elif period == "second":
            cursor.execute(command_sp)
        else:
            raise ValueError("Invalid period")
        grades = cursor.fetchall()
        for grade in grades:
            grade_proportions_dict[int(grade[0])] = grade_proportions_dict.get(int(grade[0]), 0) + 1
        return grade_proportions_dict
    except Exception as e:
        print(e)
        return grade_proportions_dict
    finally:
        connection.close()


@create_database
def return_average_by_date(period: str = None):
    '''Function that returns averages by date, including rounded subject averages and their combined average.'''
    connection = sqlite3.connect(path)
    cursor = connection.cursor()

    cursor.execute("SELECT start_date, end_date FROM periods WHERE name = 'first_period'")
    first_period = cursor.fetchone()
    cursor.execute("SELECT start_date, end_date FROM periods WHERE name = 'second_period'")
    second_period = cursor.fetchone()

    if first_period[0] != 'N/A' and first_period[1] != 'N/A' and second_period[0] != 'N/A' and second_period[1] != 'N/A':
        start_date_fp, end_date_fp = first_period
        start_date_sp, end_date_sp = second_period
    else:
        connection.close()
        return [], []

    date_filter = ""
    if period == "first":
        date_filter = f"WHERE date BETWEEN '{start_date_fp}' AND '{end_date_fp}'"
    elif period == "second":
        date_filter = f"WHERE date BETWEEN '{start_date_sp}' AND '{end_date_sp}'"
    else:
        raise ValueError("Invalid period")

    command = f"""
    WITH cumulative_grades AS (
        SELECT date, grade, weight, subject_name
        FROM grades
        {date_filter}
        ORDER BY date, subject_name
    ),
    cumulative_averages AS (
        SELECT cg1.date, cg1.subject_name,
            (SELECT SUM(cg2.grade * cg2.weight) / SUM(cg2.weight)
            FROM cumulative_grades cg2
            WHERE cg2.subject_name = cg1.subject_name AND cg2.date <= cg1.date) AS average_grade
        FROM cumulative_grades cg1
        GROUP BY cg1.date, cg1.subject_name
    ),
    general_cumulative_average AS (
        SELECT la1.date,
            AVG(la2.average_grade) AS general_average
        FROM cumulative_averages la1
        JOIN cumulative_averages la2 ON la2.date <= la1.date
        GROUP BY la1.date
    )
    SELECT 'Subject Average' AS type, date, subject_name, average_grade
    FROM cumulative_averages
    UNION ALL
    SELECT 'General Average' AS type, date, NULL AS subject_name, general_average
    FROM general_cumulative_average
    ORDER BY date, type DESC;
    """

    try:
        connection = sqlite3.connect(path)
        cursor = connection.cursor()
        cursor.execute(command)
        data = cursor.fetchall()

        data.sort(key=lambda x: x[1])

        subject_averages = {}
        final_result = []
        rounded_general_averages = []

        for record in data:
            record_type, date, subject_name, average = record

            if record_type == 'Subject Average':
                subject_averages[subject_name] = average
                final_result.append(('Subject Average', date, subject_name, average))
            elif record_type == 'General Average':

                rounded_subject_averages = {sub: round_custom(avg) for sub, avg in subject_averages.items()}

                non_rounded_general_avg = sum(subject_averages.values()) / len(subject_averages) if subject_averages else 0.0

                if rounded_subject_averages:
                    rounded_general_avg = sum(rounded_subject_averages.values()) / len(rounded_subject_averages)
                else:
                    rounded_general_avg = 0.0

                rounded_general_averages.append((date, rounded_general_avg))

                final_result.append(('General Average', date, None, non_rounded_general_avg))
                final_result.append(('Rounded General Average', date, None, rounded_general_avg))

        final_result.sort(key=lambda x: (x[1], x[0]))

        original_averages = [{'date': row[1], 'average_grade': row[3]} for row in final_result if row[0] == "General Average"]
        rounded_averages = [{'date': row[1], 'average_grade': row[3]} for row in final_result if row[0] == "Rounded General Average"]

        return original_averages, rounded_averages

    except Exception as e:
        print(e)
        return [], []
    finally:
        connection.close()


@create_database
def return_average_by_date_period(period: str = None):
    '''Function that returns averages by date, including rounded subject averages and their combined average, considering periods.'''
    if period == "first_period":
        connection = sqlite3.connect(path)
        cursor = connection.cursor()

        cursor.execute("SELECT start_date, end_date FROM periods WHERE name = 'first_period'")
        first_period = cursor.fetchone()

        start_date, end_date = first_period
    elif period == "second_period":
        connection = sqlite3.connect(path)
        cursor = connection.cursor()

        cursor.execute("SELECT start_date, end_date FROM periods WHERE name = 'second_period'")
        second_period = cursor.fetchone()

        start_date, end_date = second_period
    else:

        today = datetime.now().strftime('%Y%m%d')

        connection = sqlite3.connect(path)
        cursor = connection.cursor()

        cursor.execute("SELECT start_date, end_date FROM periods WHERE name = 'first_period'")
        first_period = cursor.fetchone()
        cursor.execute("SELECT start_date, end_date FROM periods WHERE name = 'second_period'")
        second_period = cursor.fetchone()

        if first_period[0] != 'N/A' and first_period[1] != 'N/A' and first_period[0] <= today <= first_period[1]:
            start_date, end_date = first_period
        elif second_period[0] != 'N/A' and second_period[1] != 'N/A' and first_period[1] < today <= second_period[1]:
            start_date, end_date = second_period
        else:
            start_date, end_date = second_period

    command = f"""
    WITH cumulative_grades AS (
        SELECT date, grade, weight, subject_name
        FROM grades
        WHERE date BETWEEN '{start_date}' AND '{end_date}'
        ORDER BY date, subject_name
    ),
    cumulative_averages AS (
        SELECT cg1.date, cg1.subject_name,
            (SELECT SUM(cg2.grade * cg2.weight) / SUM(cg2.weight)
            FROM cumulative_grades cg2
            WHERE cg2.subject_name = cg1.subject_name AND cg2.date <= cg1.date) AS average_grade
        FROM cumulative_grades cg1
        GROUP BY cg1.date, cg1.subject_name
    ),
    general_cumulative_average AS (
        SELECT la1.date,
            AVG(la2.average_grade) AS general_average
        FROM cumulative_averages la1
        JOIN cumulative_averages la2 ON la2.date <= la1.date
        GROUP BY la1.date
    )
    SELECT 'Subject Average' AS type, date, subject_name, average_grade
    FROM cumulative_averages
    UNION ALL
    SELECT 'General Average' AS type, date, NULL AS subject_name, general_average
    FROM general_cumulative_average
    ORDER BY date, type DESC;
    """

    try:
        cursor.execute(command)
        data = cursor.fetchall()

        data.sort(key=lambda x: x[1])

        subject_averages = {}
        final_result = []
        rounded_general_averages = []

        for record in data:
            record_type, date, subject_name, average = record

            if record_type == 'Subject Average':
                subject_averages[subject_name] = average
                final_result.append(('Subject Average', date, subject_name, average))
            elif record_type == 'General Average':

                rounded_subject_averages = {sub: round_custom(avg) for sub, avg in subject_averages.items()}

                non_rounded_general_avg = sum(subject_averages.values()) / len(subject_averages) if subject_averages else 0.0

                if rounded_subject_averages:
                    rounded_general_avg = sum(rounded_subject_averages.values()) / len(rounded_subject_averages)
                else:
                    rounded_general_avg = 0.0

                rounded_general_averages.append((date, rounded_general_avg))

                final_result.append(('General Average', date, None, non_rounded_general_avg))
                final_result.append(('Rounded General Average', date, None, rounded_general_avg))

        final_result.sort(key=lambda x: (x[1], x[0]))

        original_averages = [{'date': row[1], 'average_grade': row[3]} for row in final_result if row[0] == "General Average"]
        rounded_averages = [{'date': row[1], 'average_grade': row[3]} for row in final_result if row[0] == "Rounded General Average"]

        return original_averages, rounded_averages

    except Exception as e:
        print(e)
        return [], []
    finally:
        connection.close()


@create_database
def return_average(subject: str) -> str:
    '''function to return the average grade of a subject'''
    command = f"SELECT SUM(grade*weight)/SUM(weight) AS average_grade FROM grades WHERE subject_name = '{subject}'"
    try:
        connection = sqlite3.connect(path)
        cursor = connection.cursor()
        cursor.execute(command)
        average = cursor.fetchone()
        average_grade = average[0]
        return f'{average_grade:.2f}' if average_grade is not None else 'N/A'
    except Exception as e:
        print(e)
        return 'N/A'
    finally:
        connection.close()


@create_database
def return_average_by_period(subject: str, start_date, end_date) -> str:
    '''function to return the average grade of a subject between two dates'''
    command = f"""
    SELECT SUM(grade*weight)/SUM(weight) AS average_grade 
    FROM grades 
    WHERE subject_name = '{subject}' AND date BETWEEN '{start_date}' AND '{end_date}'
    """
    try:
        connection = sqlite3.connect(path)
        cursor = connection.cursor()
        cursor.execute(command)
        average = cursor.fetchone()
        average_grade = average[0]
        return f'{average_grade:.2f}' if average_grade is not None else 'N/A'
    except Exception as e:
        print(e)
        return 'N/A'
    finally:
        connection.close()


@create_database
def return_average_by_period_bis(subject: str) -> str:
    '''function to return the average grade of a subject based on the current period'''
    today = datetime.now().strftime('%Y%m%d')

    connection = sqlite3.connect(path)
    cursor = connection.cursor()

    cursor.execute("SELECT start_date, end_date FROM periods WHERE name = 'first_period'")
    first_period = cursor.fetchone()
    cursor.execute("SELECT start_date, end_date FROM periods WHERE name = 'second_period'")
    second_period = cursor.fetchone()

    if first_period[0] != 'N/A' and first_period[1] != 'N/A' and first_period[0] <= today <= first_period[1]:
        start_date, end_date = first_period
    elif second_period[0] != 'N/A' and second_period[1] != 'N/A' and first_period[1] < today <= second_period[1]:
        start_date, end_date = second_period
    else:
        start_date, end_date = second_period

    command = f"""
    SELECT SUM(grade*weight)/SUM(weight) AS average_grade 
    FROM grades 
    WHERE subject_name = '{subject}' AND date BETWEEN '{start_date}' AND '{end_date}'
    """
    try:
        cursor.execute(command)
        average = cursor.fetchone()
        average_grade = average[0]
        return f'{average_grade:.2f}' if average_grade is not None else 'N/A'
    except Exception as e:
        print(e)
        return 'N/A'
    finally:
        connection.close()


@create_database
def return_averages() -> list:
    '''function to return all the averages grouped by subject'''
    command = "SELECT subject_name, SUM(grade*weight)/SUM(weight) AS average_grade FROM grades GROUP BY subject_name;"
    averages_list = []
    try:

        connection = sqlite3.connect(path)
        cursor = connection.cursor()
        cursor.execute(command)
        averages = cursor.fetchall()

        for subject, average in averages:
            averages_tuple = (subject, round(average, 2))
            averages_list.append(averages_tuple)

        subjects = [x[0] for x in list_subjects()]

        subjects_set = set(subjects)
        subjects_check = []

        for subject in averages_list:
            subjects_check.append(subject[0])

        subjects_check_set = set(subjects_check)
        subjects_to_add = (subjects_set-subjects_check_set)

        if len(subjects_to_add) == 0:
            return averages_list
        for subject in subjects_to_add:
            subject_tuple = (subject, 'N/A')
            averages_list.append(subject_tuple)
        return averages_list

    except Exception as e:
        print(e, command)
        return averages_list
    finally:
        connection.close()


@create_database
def return_averages_by_period() -> list:
    '''function to return all the averages grouped by subject considering periods'''
    today = datetime.now().strftime('%Y%m%d')

    connection = sqlite3.connect(path)
    cursor = connection.cursor()

    cursor.execute("SELECT start_date, end_date FROM periods WHERE name = 'first_period'")
    first_period = cursor.fetchone()
    cursor.execute("SELECT start_date, end_date FROM periods WHERE name = 'second_period'")
    second_period = cursor.fetchone()

    if first_period[0] != 'N/A' and first_period[1] != 'N/A' and first_period[0] <= today <= first_period[1]:
        start_date, end_date = first_period
    elif second_period[0] != 'N/A' and second_period[1] != 'N/A' and first_period[1] < today <= second_period[1]:
        start_date, end_date = second_period
    else:
        start_date, end_date = second_period

    command = f"""
    SELECT subject_name, SUM(grade*weight)/SUM(weight) AS average_grade 
    FROM grades 
    WHERE date BETWEEN '{start_date}' AND '{end_date}'
    GROUP BY subject_name;
    """
    averages_list = []
    try:
        cursor.execute(command)
        averages = cursor.fetchall()

        for subject, average in averages:
            averages_tuple = (subject, round(average, 2))
            averages_list.append(averages_tuple)

        subjects = [x[0] for x in list_subjects()]

        subjects_set = set(subjects)
        subjects_check = []

        for subject in averages_list:
            subjects_check.append(subject[0])

        subjects_check_set = set(subjects_check)
        subjects_to_add = (subjects_set - subjects_check_set)

        if len(subjects_to_add) == 0:
            return averages_list
        for subject in subjects_to_add:
            subject_tuple = (subject, 'N/A')
            averages_list.append(subject_tuple)
        return averages_list

    except Exception as e:
        print(e, command)
        return averages_list
    finally:
        connection.close()


@create_database
def return_general_average():
    '''function to return the general average'''
    command = """
    SELECT SUM(average_grade) / COUNT(subject_name) AS overall_average
    FROM (
        SELECT subject_name, 
        SUM(grade * weight) / SUM(weight) AS average_grade
        FROM grades
        GROUP BY subject_name
    ) AS subject_averages;
    """
    try:
        connection = sqlite3.connect(path)
        cursor = connection.cursor()
        cursor.execute(command)
        average = cursor.fetchone()
        general_average = average[0]
        return f'{general_average:.2f}'
    except Exception as e:
        print(e)
        return 'N/A'
    finally:
        connection.close()


@create_database
def return_general_average_by_period():
    '''function to return the general average considering the current period'''

    today = datetime.now().strftime('%Y%m%d')

    connection = sqlite3.connect(path)
    cursor = connection.cursor()

    cursor.execute("SELECT start_date, end_date FROM periods WHERE name = 'first_period'")
    first_period = cursor.fetchone()
    cursor.execute("SELECT start_date, end_date FROM periods WHERE name = 'second_period'")
    second_period = cursor.fetchone()

    if first_period[0] != 'N/A' and first_period[1] != 'N/A' and first_period[0] <= today <= first_period[1]:
        start_date, end_date = first_period
    elif second_period[0] != 'N/A' and second_period[1] != 'N/A' and first_period[1] < today <= second_period[1]:
        start_date, end_date = second_period
    else:
        start_date, end_date = second_period

    command = f"""
    SELECT SUM(average_grade) / COUNT(subject_name) AS overall_average
    FROM (
        SELECT subject_name, 
        SUM(grade * weight) / SUM(weight) AS average_grade
        FROM grades
        WHERE date BETWEEN '{start_date}' AND '{end_date}'
        GROUP BY subject_name
    ) AS subject_averages;
    """
    try:
        cursor.execute(command)
        average = cursor.fetchone()
        general_average = average[0]
        return f'{general_average:.2f}' if general_average is not None else 'N/A'
    except Exception as e:
        print(e)
        return 'N/A'
    finally:
        connection.close()


@create_database
def delete_grade(id_: str):
    '''function that deletes a grade gived its id'''
    command = f"DELETE FROM grades WHERE id = {int(id_[13:])};"
    try:
        connection = sqlite3.connect(path)
        cursor = connection.cursor()
        cursor.execute(command)
        connection.commit()
        return True
    except Exception as e:
        print(e)
        return False
    finally:
        connection.close()


@create_database
def edit_grade(data: dict):
    '''function that edits a grade given its id'''
    command = f"UPDATE grades SET subject_name = '{data['subject']}', grade = '{data['grade']}', date = '{data['date']}', weight = '{data['grade_weight']}', type = '{data['type']}' WHERE id = '{int(data['grade_id'])}'"
    try:
        connection = sqlite3.connect(path)
        cursor = connection.cursor()
        cursor.execute(command)
        connection.commit()
        return True
    except Exception as e:
        print(e)
        return False
    finally:
        connection.close()


@create_database
def set_primary_colour(colour: str):
    '''function that sets a primary color'''
    check_list = []
    try:
        connection = sqlite3.connect(path)
        cursor = connection.cursor()
        command_first = "SELECT * FROM settings"
        cursor.execute(command_first)
        for x in cursor:
            check_list.append(x)
        if check_list:
            command = f"UPDATE settings SET primary_colour = '{colour}' WHERE id = 1"
            cursor.execute(command)
            connection.commit()
            return True
        command = f"INSERT INTO settings (primary_colour) VALUES ('{colour}')"
        cursor.execute(command)
        connection.commit()
        return True
    except Exception as e:
        print(e)
        return False
    finally:
        connection.close()


@create_database
def delete_subject(subject: str):
    '''function that deletes a subject'''
    command = f"DELETE FROM subject_list WHERE subject = '{subject}'"
    command_2 = f"DELETE FROM grades WHERE subject_name = '{subject}'"
    try:
        connection = sqlite3.connect(path)
        cursor = connection.cursor()
        cursor.execute(command)
        cursor.execute(command_2)
        connection.commit()
        return True
    except Exception as e:
        print(e)
        return False
    finally:
        connection.close()


@create_database
def rename_subject(old_subject_name: str, new_subject_name: str):
    '''function that renames a subject'''
    command = f"UPDATE subject_list SET subject = '{new_subject_name}' WHERE subject = '{old_subject_name}'"
    command_2 = f"UPDATE grades SET subject_name = '{new_subject_name}' WHERE subject_name = '{old_subject_name}'"
    try:
        connection = sqlite3.connect(path)
        cursor = connection.cursor()
        cursor.execute(command)
        cursor.execute(command_2)
        connection.commit()
        print("subject renamed")
        return True
    except sqlite3.IntegrityError:
        return "duplicate subject"
    except Exception as e:
        print(e)
        return False
    finally:
        connection.close()


@create_database
def set_objective(subject: str, objective: float):
    '''function that sets an objective for a subject'''
    command = f"UPDATE subject_list SET objective = '{objective}' WHERE subject = '{subject}'"
    try:
        connection = sqlite3.connect(path)
        cursor = connection.cursor()
        cursor.execute(command)
        connection.commit()
        return True
    except Exception as e:
        print(e)
        return False
    finally:
        connection.close()


@create_database
def set_period(period_name: str, start_date, end_date):
    '''function that sets a period'''
    if start_date > end_date:
        return 'invalid dates'

    if period_name == 'second_period':
        connection = sqlite3.connect(path)
        cursor = connection.cursor()
        cursor.execute("SELECT start_date FROM periods WHERE name = 'first_period'")
        first_period_end_date = cursor.fetchone()[0]
        if first_period_end_date != 'N/A' and first_period_end_date > start_date:
            return 'invalid dates'
        connection.close()

    command = f"UPDATE periods SET start_date = '{start_date}', end_date = '{end_date}' WHERE name = '{period_name}'"
    try:
        connection = sqlite3.connect(path)
        cursor = connection.cursor()
        cursor.execute(command)
        connection.commit()
        return True
    except Exception as e:
        print(e)
        return False
    finally:
        connection.close()


@create_database
def get_periods():
    '''function that returns all periods'''
    command = "SELECT * FROM periods"
    result = []
    try:
        connection = sqlite3.connect(path)
        cursor = connection.cursor()
        cursor.execute(command)
        periods = cursor.fetchall()
        for _,start,end in periods:
            result.append((start,end))
        return result
    except Exception as e:
        print(e)
        return [('N/A', 'N/A'), ('N/A', 'N/A')]
    finally:
        connection.close()


@create_database
def objective_achievement_subject(subject: str):
    '''function that returns the achievement of the objective of a subject'''
    average = float(return_average(subject))
    command = f"SELECT objective FROM subject_list WHERE subject = '{subject}'"
    try:
        connection = sqlite3.connect(path)
        cursor = connection.cursor()
        cursor.execute(command)
        objective = cursor.fetchone()
        if average == 'N/A' or objective[0] is None:
            return "not enough data"
        if average >= objective[0]:
            return "completely reached"
        if round_custom(average) >= objective[0]:
            return "reached"
        if  average >= objective[0] - 1:
            return "almost reached"
        return "not reached"
    except Exception as e:
        print(e)
        return False
    finally:
        connection.close()


@create_database
def objective_achievement_subject_by_period(subject: str):
    '''function that returns the achievement of the objective of a subject considering periods and today's date'''
    today = datetime.now().strftime('%Y%m%d')

    connection = sqlite3.connect(path)
    cursor = connection.cursor()

    cursor.execute("SELECT start_date, end_date FROM periods WHERE name = 'first_period'")
    first_period = cursor.fetchone()
    cursor.execute("SELECT start_date, end_date FROM periods WHERE name = 'second_period'")
    second_period = cursor.fetchone()

    if first_period[0] != 'N/A' and first_period[1] != 'N/A' and first_period[0] <= today <= first_period[1]:
        start_date, end_date = first_period
    elif second_period[0] != 'N/A' and second_period[1] != 'N/A' and first_period[1] < today <= second_period[1]:
        start_date, end_date = second_period
    else:
        start_date, end_date = second_period

    average = return_average_by_period(subject, start_date, end_date)
    average = float(average) if average != 'N/A' else average
    command = f"SELECT objective FROM subject_list WHERE subject = '{subject}'"
    try:
        cursor.execute(command)
        objective = cursor.fetchone()
        if average == 'N/A' or objective[0] is None:
            return "not enough data"
        if average >= objective[0]:
            return "completely reached"
        if round_custom(average) >= objective[0]:
            return "reached"
        if average >= objective[0] - 1:
            return "almost reached"
        return "not reached"
    except Exception as e:
        print(e)
        return False
    finally:
        connection.close()


@create_database
def objective_achievement():
    '''function that returns the achievement of the objectives'''
    subjects_averages = return_averages()
    subject_number = len([x[0] for x in subjects_averages])
    result = {}
    count_result = {
        'completely reached': 0,
        'reached': 0,
        'almost reached': 0,
        'not reached': 0,
        'not enough data': 0
    }
    for subject, average in subjects_averages:
        command = f"SELECT objective FROM subject_list WHERE subject = '{subject}'"
        try:
            connection = sqlite3.connect(path)
            cursor = connection.cursor()
            cursor.execute(command)
            objective = cursor.fetchone()
            if average == 'N/A' or objective[0] is None:
                result[subject] = "not enough data"
                continue
            if average >= objective[0]:
                result[subject] = "completely reached"
                continue
            if round_custom(average) >= objective[0]:
                result[subject] = "reached"
                continue
            if  average >= objective[0] - 1:
                result[subject] = "almost reached"
                continue
            result[subject] = "not reached"
            continue
        except Exception as e:
            print(e)
            return False
        finally:
            connection.close()
    for value in result.values():
        count_result[value] = count_result.get(value) + 1
    return result, count_result, subject_number


@create_database
def objective_achievement_by_period():
    '''function that returns the achievement of the objectives considering periods and today's date'''
    today = datetime.now().strftime('%Y%m%d')

    connection = sqlite3.connect(path)
    cursor = connection.cursor()

    cursor.execute("SELECT start_date, end_date FROM periods WHERE name = 'first_period'")
    first_period = cursor.fetchone()
    cursor.execute("SELECT start_date, end_date FROM periods WHERE name = 'second_period'")
    second_period = cursor.fetchone()

    if first_period[0] != 'N/A' and first_period[1] != 'N/A' and first_period[0] <= today <= first_period[1]:
        start_date, end_date = first_period
    elif second_period[0] != 'N/A' and second_period[1] != 'N/A' and first_period[1] < today <= second_period[1]:
        start_date, end_date = second_period
    else:
        start_date, end_date = second_period

    subjects_averages = return_averages_by_period()
    subject_number = len([x[0] for x in subjects_averages])
    result = {}
    count_result = {
        'completely reached': 0,
        'reached': 0,
        'almost reached': 0,
        'not reached': 0,
        'not enough data': 0
    }
    for subject, average in subjects_averages:
        command = f"SELECT objective FROM subject_list WHERE subject = '{subject}'"
        try:
            cursor.execute(command)
            objective = cursor.fetchone()
            if average == 'N/A' or objective[0] is None:
                result[subject] = "not enough data"
                continue
            if average >= objective[0]:
                result[subject] = "completely reached"
                continue
            if round_custom(average) >= objective[0]:
                result[subject] = "reached"
                continue
            if average >= objective[0] - 1:
                result[subject] = "almost reached"
                continue
            result[subject] = "not reached"
            continue
        except Exception as e:
            print(e)
            return False
    for value in result.values():
        count_result[value] = count_result.get(value, 0) + 1
    return result, count_result, subject_number
