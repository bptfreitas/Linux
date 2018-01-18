#!/usr/bin/python

import urllib
import urllib2
import cookielib

url = 'http://biblioteca.ifrs.edu.br/biblioteca/index.php'
form_data = {'login_acesso': 's2108047', 'senha_acesso': '040219'}
params = urllib.urlencode(form_data)
response = urllib2.urlopen(url, params)
data = response.read()

print data
