document.addEventListener('DOMContentLoaded', function() {
    window.addEventListener('message', function(event) {
        console.log('Message reçu:', event.data);

        var panel = document.getElementById('panel');
        var panelText = document.getElementById('panel-text');

        if (event.data.type === 'afficherPanneau') {
            console.log('Afficher le panneau');
            showPanneau(event.data.text);
        } else if (event.data.type === 'cacherPanneau') {
            console.log('Cacher le panneau');
            hidePanneau();
        }
    });
});

function showPanneau(text) {
    var panel = document.getElementById('panel');
    var panelText = document.getElementById('panel-text');

    panel.style.display = 'block';
    panelText.innerText = text;
}

function hidePanneau() {
    var panel = document.getElementById('panel');
    panel.style.display = 'none';
}