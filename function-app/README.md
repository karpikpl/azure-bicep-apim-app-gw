# Python Function App - Echo Service

Simple echo function that returns request information.

## Local Development

```powershell
cd function-app
python -m venv .venv
.venv\Scripts\Activate.ps1
pip install -r requirements.txt
func start
```

## Deploy to Azure

```powershell
cd function-app
func azure functionapp publish <function-app-name>
```
