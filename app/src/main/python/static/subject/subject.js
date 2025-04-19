document.addEventListener("DOMContentLoaded", function () {

    getRequest();

    var button = document.getElementById("add-grade-button");
    button.addEventListener("click", function () {
        showSection(button);
    });

    var formGrade = document.getElementById("add-grade-section");
    formGrade.addEventListener('submit', function (event) {
        event.preventDefault();

        var grade = document.getElementById("grade").value;
        var gradeWeight = document.getElementById("grade-weight").value;
        var regex = /^[a-zA-z]+$/;
        if (!!regex.test(grade) && !!regex.test(gradeWeight)) {
            window.alert("letters detected in the grade or in the grade weight");
            return false;
        };

        let submitButton = document.getElementById("submit-button");
        if (submitButton.textContent == "Add grade") {
            var data = {
                subject: document.title,
                grade: grade,
                date: document.getElementById("grade-date").value,
                grade_weight: gradeWeight,
                type: document.getElementById('type').value
            };
            fetch("/addGrade", {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(data)
            })
            .then(res => res.json())
            .then(data => {
                if (data.ok) {
                    window.alert(data.message);
                    window.location.reload();
                }
                else {
                    window.alert(data.message);
                }
            })
            .catch(err => console.error('error: ', err));
        } else {
            sendEditGrade();
        }
    });
});

function showSection(button) {
    document.getElementById("add-grade-section").style.display = 'flex';
    button.style.display = 'none';
};

function cancelAddGrade() {
    document.getElementById("add-grade-section").style.display = 'none';
    document.getElementById("add-grade-button").style.display = 'flex';
}

function deleteGrade(id) {
    var data = {
        id: id
    };

    fetch("/deleteGrade", {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify(data)
    })
    .then(res => res.json())
    .then(data => {
    if (data.ok) {
        window.alert(data.message);
        window.location.reload();
    }
    else {
        window.alert(data.message);
    }
    })
    .catch(err => console.error('error: ', err));
}

function goBack() {
    window.location.href = "/";
}

function editGrade(id_, grade_, date_, weight_, type_) {
    showSection(document.getElementById("add-grade-button"));

    let grade = document.getElementById("grade");
    grade.value = grade_;

    let date = document.getElementById("grade-date");
    date.value = date_;

    let weight = document.getElementById("grade-weight");
    weight.value = weight_;

    let type = document.getElementById("type");
    type.value = type_;

    let submitButton = document.getElementById("submit-button");
    submitButton.innerHTML = '<span class="material-icons-outlined material-icons"> done </span>';
    window.global_id = id_ // needed to use a global variable
}

function sendEditGrade() {
    var grade = document.getElementById("grade").value;
    var gradeWeight = document.getElementById("grade-weight").value;
    var regex = /^[a-zA-z]+$/;
    if (!!regex.test(grade) && !!regex.test(gradeWeight)) {
        window.alert("letters detected in the grade or in the grade weight");
        return false;
    };

    let data = {
        subject: document.title,
        grade: grade,
        date: document.getElementById("grade-date").value,
        grade_weight: gradeWeight,
        type: document.getElementById('type').value,
        grade_id: window.global_id
    };

    console.log(data)
    fetch("/editGrade", {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify(data)
    })
    .then(res => {return res.json()})
    .then(data => {
        if (data.ok) {
            window.alert(data.message);
            window.location.reload();
        } else {
            window.alert(data.message);
        }
    })
}

function getRequest() {
    fetch("/changePeriod?subject=" + document.title + "&period=" + document.getElementById("period-choice").value)
    .then(res => res.text())
    .then(data => {
        document.getElementById("grade-content").innerHTML = data;
    })
}

function changePeriod(period) {
    var data = {
        period: period,
        subject: document.title
    };

    fetch("/changePeriod", {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify(data)
    })
    .then(res => res.text(), getRequest())
    .catch(err => console.error('error: ', err));
}

function deleteSubject(subject) {

    var data = {
        subject_to_delete: subject
    };

    fetch("/deleteSubject", {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify(data)
    })
    .then(res => res.json())
    .then(data => {
    if (data.ok) {
        window.alert(data.message);
        window.location.href = '/';
    }
    else {
        window.alert(data.message);
    }
    })
    .catch(err => console.error('error: ', err));
}

function renameSubject(subject) {

    var new_name = prompt("Insert new name for subject: " + subject).toUpperCase();

    if (new_name == null) {
        return false;
    }

    var data = {
        subject_to_rename: subject,
        new_name: new_name
    };

    fetch("/renameSubject", {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify(data)
    })
    .then(res => res.json())
    .then(data => {
    if (data.ok) {
        window.alert(data.message);
        window.location.href = '/';
    }
    else {
        window.alert(data.message);
    }
    })
    .catch(err => console.error('error: ', err));
}