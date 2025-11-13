import azure.functions as func
import logging
import json

app = func.FunctionApp(http_auth_level=func.AuthLevel.FUNCTION)

@app.route(route="echo")
def echo(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('Echo function received a request.')

    try:
        req_body = req.get_json()
    except ValueError:
        req_body = {}

    response_data = {
        'method': req.method,
        'url': req.url,
        'headers': dict(req.headers),
        'params': dict(req.params),
        'body': req_body
    }

    return func.HttpResponse(
        json.dumps(response_data, indent=2),
        mimetype="application/json",
        status_code=200
    )
