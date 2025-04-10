# Round Robin Template

Based on python Jinj2 template engine, the round robin core circuit
is generated to support a wide range of requester number based on
a verilog code, supported by open source tools. Using for loop and
a break statement wasn't possible with Icarus v5.

The template is derived from the original code only handling
4 or 8 requesters, saved in  `orig.axicb_round_robin_core.sv`.

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
