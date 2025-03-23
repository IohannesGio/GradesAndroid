document.addEventListener("DOMContentLoaded", function () {

    fetch('/index-content')
    .then(response => response.text())
    .then(data => {
        document.getElementById('main-content').innerHTML = data;
        var formSubject = document.getElementById("add-subject-section");

        formSubject.addEventListener('submit', function (event) {
            event.preventDefault();

            var subject = document.getElementById("subject").value.replace(/\s+/g, '_');
            var regex = /^[a-zA-Z_]+$/;
            if (!regex.test(subject)) {
                window.alert("special characters or numbers in subject name");
                return false;
            };

            var data = {
                subject: subject,
            };

            fetch("/addSubject", {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(data)
            })
            .then(res =>  res.json())
            .then(data => {
            if (data.ok) {
                window.alert(data.message);
                window.location.reload();
            } else {
                window.alert(data.message);
            }
            })
            .catch(err => console.error('error: ', err));
        });

        })
    .catch(error => console.error('Errore nel caricamento:', error));

    document.querySelectorAll('.nav-item').forEach(item => {
        item.addEventListener('click', function(event) {
            event.preventDefault();
            document.querySelector('.nav-item.active')?.classList.remove('active');
            this.classList.add('active');
        });
    });
});

function showSection(button) {
    document.getElementById("add-subject-section").style.display = 'flex';
    document.getElementById(button).style.display = 'none';
};

function cancelAddSubject() {
    document.getElementById("add-subject-section").style.display = 'none';
    document.getElementById("add-subject-button").style.display = 'flex';
};

function loadContent(id) {
    if (id === "home") {
        fetch('/index-content')
        .then(response => response.text())
        .then(data => {
            document.getElementById('main-content').innerHTML = data;
        })
        .catch(error => console.error('Errore nel caricamento:', error));
    }
    if (id === "stats") {
        fetch('/stats')
        .then(response => response.text())
        .then(data => {
            document.getElementById('main-content').innerHTML = data;
            function gradesDistribution() {
                let grades_dict = JSON.parse(document.getElementById("grade-bar-fp").dataset.value);
                let grades_dict_sp = JSON.parse(document.getElementById("grade-bar-sp").dataset.value);

                const ctx = document.getElementById('bar-grade-graph').getContext('2d');
                const config = {
                    type: 'bar',
                    data: {
                        labels: Object.keys(grades_dict),
                        datasets: [
                            {
                                label: 'First Period',
                                data: Object.values(grades_dict),
                                backgroundColor: '#a37cf7',
                                borderColor: '#a37cf7',
                                borderWidth: 1
                            },
                            {
                                label: 'Second Period',
                                data: Object.values(grades_dict_sp),
                                backgroundColor: '#f77c7c',
                                borderColor: '#f77c7c',
                                borderWidth: 1
                            }
                        ]
                    },
                    options: {
                        responsive: true,
                        maintainAspectRatio: false,
                        scales: {
                            x: {
                                title: {
                                    display: true,
                                    text: 'Grade'
                                }
                            },
                            y: {
                                beginAtZero: true,
                                ticks: {
                                    stepSize: 1
                                },
                                title: {
                                    display: true,
                                    text: 'Number of appereances'
                                }
                            }
                        }
                    }
                };
                new Chart(ctx, config);
            }
            gradesDistribution();

            document.getElementById('bar-grade-graph').addEventListener('touchstart', function(e) {
                e.preventDefault();
            });

            document.getElementById('average-grade-over-time').addEventListener('touchstart', function(e) {
                e.preventDefault();
            });

            fetch('/getAverageByDate', {
                method: 'GET',
                cache: 'no-store'
            })
            .then(response => response.json())
            .then(data => {

                const dataMainFp = data.data_fp;
                const roundedDataFp = data.data_rounded_fp;
                const dataMainSp = data.data_sp;
                const roundedDataSp = data.data_rounded_sp;

                const uniqueDatesFp = [...new Set(dataMainFp.map(item => item.date))].sort();
                const uniqueDatesSp = [...new Set(dataMainSp.map(item => item.date))].sort();

                const labelsFp = uniqueDatesFp.map((_, index) => `${index + 1}°`);
                const labelsSp = uniqueDatesSp.map((_, index) => `${index + 1}°`);

                const getDataMap = (dataList) => {
                    const map = {};
                    dataList.forEach(item => { map[item.date] = item.average_grade; });
                    return map;
                };

                const mainFpMap = getDataMap(dataMainFp);
                const roundedFpMap = getDataMap(roundedDataFp);
                const mainSpMap = getDataMap(dataMainSp);
                const roundedSpMap = getDataMap(roundedDataSp);

                const mainAveragesFp = uniqueDatesFp.map(date => mainFpMap[date] || null);
                const roundedAveragesFp = uniqueDatesFp.map(date => roundedFpMap[date] || null);
                const mainAveragesSp = uniqueDatesSp.map(date => mainSpMap[date] || null);
                const roundedAveragesSp = uniqueDatesSp.map(date => roundedSpMap[date] || null);

                const maxLength = Math.max(labelsFp.length, labelsSp.length);
                const labels = Array.from({ length: maxLength }, (_, index) => `${index + 1}°`);

                const ctx = document.getElementById('average-grade-over-time').getContext('2d');
                new Chart(ctx, {
                    type: 'line',
                    data: {
                        labels: labels,
                        datasets: [{
                            label: 'First Period - Average Grade',
                            data: mainAveragesFp,
                            fill: false,
                            borderColor: '#a37cf7',
                            backgroundColor: '#a37cf7',
                            tension: 0.1
                        },
                        {
                            label: 'First Period - Rounded Average Grade',
                            data: roundedAveragesFp,
                            fill: false,
                            borderColor: '#f774a3',
                            backgroundColor: '#f774a3',
                            tension: 0.1
                        },
                        {
                            label: 'Second Period - Average Grade',
                            data: mainAveragesSp,
                            fill: false,
                            borderColor: '#77c9f7',
                            backgroundColor: '#77c9f7',
                            tension: 0.1
                        },
                        {
                            label: 'Second Period - Rounded Average Grade',
                            data: roundedAveragesSp,
                            fill: false,
                            borderColor: '#f7c977',
                            backgroundColor: '#f7c977',
                            tension: 0.1
                        }]
                    },
                    options: {
                        responsive: true,
                        maintainAspectRatio: false,
                        scales: {
                            x: {
                                title: {
                                    display: true,
                                    text: 'Date'
                                }
                            },
                            y: {
                                title: {
                                    display: true,
                                    text: 'Average Grade'
                                },
                                beginAtZero: true,
                                min: 0,
                                max: 10
                            }
                        }
                    }
                });
            });
        })
        .catch(error => console.error('Errore nel caricamento:', error));
    }
    if (id === "settings") {
        fetch('/settings')
        .then(response => response.text())
        .then(data => {
            document.getElementById('main-content').innerHTML = data;
        })
        .catch(error => console.error('Errore nel caricamento:', error));
    }
}

function redirect(subject) {

    var data = {
        subject_redirect: subject
    };

    fetch("/redirect", {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify(data)
    })
    .then(res => res.json())
    .then(data => {
    if (data.redirect) {
        window.location.href = data.redirect;
    }
    else {
        window.alert("error while going to subject: " + subject);
    }
    })
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
        loadContent('settings');
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
        loadContent('settings');
    }
    else {
        window.alert(data.message);
    }
    })
    .catch(err => console.error('error: ', err));
}

function setObjective(subject) {

    var new_objective = prompt("Insert new objective for " + subject);

    if (new_objective != null) {
        var data = {
            subject: subject,
            objective: new_objective
        };

        fetch("/setObjective", {
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
            loadContent('settings');
        }
        else {
            window.alert(data.message);
        }
        })
        .catch(err => console.error('error: ', err));
    }
}

function showPeriodSection(period, button) {
    document.getElementById(period).style.display = 'flex';
    document.getElementById(button).style.display = 'none';
}

function cancelPeriod(period, button) {
    document.getElementById(period).style.display = 'none';
    document.getElementById(button).style.display = 'flex';
}

function setPeriod(period) {
    var start = document.getElementById("start-date-" + period).value;
    var end = document.getElementById("end-date-" + period).value;

    var data = {
        period: (period === "first-period") ? "first_period" : "second_period",
        start: start,
        end: end
    };

    fetch("/setPeriod", {
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
        loadContent('settings');
    }
    else {
        window.alert(data.message);
    }
    })
    .catch(err => console.error('error: ', err));
}
