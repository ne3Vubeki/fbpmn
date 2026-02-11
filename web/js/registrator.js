_flutter._registeredApp = _flutter._registeredApp || {};

window.addEventListener('qp_register_app_channel', function (event) {
    const app = event.detail;
    const appName = app.getApp();
    if (_flutter._registeredApp[appName]) {
        app.addListenerJs(relayEventToDart);
    }
});

window.addEventListener('load', async function (ev) {
    _flutter.loader.load({
        onEntrypointLoaded: async function onEntrypointLoaded(engineInitializer) {
            let engine = await engineInitializer.initializeEngine({
                multiViewEnabled: true,
            });
            let fbpmn = await engine.runApp();
            fbpmn.addView({
                hostElement: document.querySelector('#q-wasm-container-fbpmn'),
                initialData: {
                }
            });
            _flutter._registeredApp['fbpmn'] = {
                app: fbpmn
            };
        }
    });
});

function relayEventToDart(event) {
    const e = event.getActionJS();
    switch (e) {
        case 'relay':
            const targets = event.getTargetsJS();
            targets.forEach((target) => {
                const targetArr = target.split('.');
                const app = _flutter._registeredApp[targetArr[0]];
                if (app) {
                    const view = app.view[targetArr[1] || targetArr[0]];
                    if (view) {
                        view.emitToDart(event);
                    }
                }
            });
            break;
        default:
            break;
    }
}

