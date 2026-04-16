# Round Robin Template

Based on python Jinja2 template engine, the round robin core circuit
is generated to support a wide range of requester number based on
a verilog code, supported by open source tools. Using for loop and
a break statement wasn't possible with Icarus v5.

# How To Generate

First setup the python flow:
```python
# Create the virtualenv
python3 -m venv venv
# Activate the virtualenv
source venv/bin/activate
# Install the dependencies
pip install -r requirements.txt
```

To generate a new robin robin code, call the script with the
number of max requesters to support:

```python
python3 ./template_round_robin.py 32
```
