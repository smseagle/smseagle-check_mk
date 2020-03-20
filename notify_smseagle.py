#!/usr/bin/env python
#
# ============================== SUMMARY =====================================
#
# Summary : This script sends SMS alerts from Check MK via SMSEagle device. 
#			
# Program : notify_smseagle.py
# Version : 1.0
# Date : Mar 20, 2020
# Author : Bernd Nies, SMSEgle Team 
# Forked from: https://www.nies.ch/doc/it/check-mk-smseagle.en.php
# License : BSD License 2.0
# Copyright (c) 2020, Bernd Nies, SMSEagle 
#
# ============================= SETUP ==========================================
#
# SMSEAGLE SETUP
#
# Create a new user for this script in SMSEagle device.
# This user will be referenced below as: SMSEAGLEUSER and SMSEAGLEPASSWORD 
# Replace SMSEAGLEUSER and SMSEAGLEPASSWORD in script below with your values.
#
# CHECK_MK SETUP
#
# 1. Copy the script as site user into the folder ~/local/share/check_mk/notifications 
# 2. Make the executeable
# 
# su - mysite
# cp /var/tmp/notify_smseagle.py ~/local/share/check_mk/notifications
# chmod 755 ~/local/share/check_mk/notifications/notify_smseagle.py
# omd reload
#
# 

"""
Check_MK SMS Notification
=========================

Alerting via SMSEagle device(s), defined in EagleHosts. If all
SMSEagle hosts fail to send the SMS, the alert is sent via email to MailTo.
"""

import urllib
import urllib2
import smtplib
import re
import sys
import socket
from os import environ
from email.mime.text import MIMEText



### Configuration Parameters

EagleHosts    = [ '1.2.3.4', '5.6.7.8' ]
EagleLogin    = 'SMSEAGLEUSER'
EaglePassword = 'SMSEAGLEPASSWORD'

MailFrom      = 'monitoring@example.com'
MailTo        = 'myemail@example.com'
MailHosts     = [ 'localhost', 'smtp1.example.com']
MailPort      = 25


# ----------------------------------------------------------------------------
# Complain 
# ----------------------------------------------------------------------------

def complain(error):
    print error
    msg = MIMEText(error)
    msg['To'] = MailTo
    msg['From'] = MailFrom
    msg['Subject'] = 'Check_MK: SMS Notification Error'
    MessageSent  = False

    for host in MailHosts:
        if not MessageSent:
            try:
                server = smtplib.SMTP(host, MailPort)
                server.sendmail(MailFrom, MailTo, msg.as_string())
                server.quit()
            except socket.error as e:
                print "Could not connect to " + host + ": " + str(e) 
            except smtplib.SMTPException as e:
                print "Sending email failed: " + str(e)
            except:
                print "Unknown error:", sys.exc_info()[0]
            else:
                MessageSent = True
                break
    return



# ----------------------------------------------------------------------------
# Format Message 
# ----------------------------------------------------------------------------

def FormatMessage():
    """
    Format the SMS message using the environment variables given by Check_MK.
    See https://checkmk.com/cms_notifications.html for details.
    """ 
    if 'NOTIFY_WHAT' in environ:
        if environ['NOTIFY_WHAT'] == 'HOST':
            msg = "%s %s: %s (%s)" % (
                  environ['NOTIFY_NOTIFICATIONTYPE'], 
                  environ['NOTIFY_HOSTNAME'],
                  environ['NOTIFY_HOSTOUTPUT'],
                  environ['NOTIFY_SHORTDATETIME'])
        elif environ['NOTIFY_WHAT'] == 'SERVICE':
            msg = "%s %s: %s %s (%s)" % (
                  environ['NOTIFY_NOTIFICATIONTYPE'],
                  environ['NOTIFY_HOSTNAME'],
                  environ['NOTIFY_SERVICEDESC'],
                  environ['NOTIFY_SERVICEOUTPUT'],
                  environ['NOTIFY_SHORTDATETIME'])
        else:
            msg = "Unknown notification method: " + environ['NOTIFY_WHAT']
    else:
        msg = "Environment variable NOTIFY_WHAT not defined."
    return msg




# ----------------------------------------------------------------------------
# Send SMS via SMSEagle
# ----------------------------------------------------------------------------

def sendEagleSMS(to,message):
    """
    Sending SMS via SMSEagle HTTP API. Uses hosts defined in list EagleHosts.
    Upon failure an email with the error is sent and next host is used.
    """
    query_args   = { 'login':EagleLogin, 'pass':EaglePassword, 'to':to,
                     'message':message }
    encoded_args = urllib.urlencode(query_args)
    MessageSent  = False
    ErrorMessage = ''

    for host in EagleHosts:
        url =  'http://%s/http_api/send_sms?%s' % (host, encoded_args)
        if not MessageSent:
            try:
                result = urllib2.urlopen(url).read()
            except urllib2.HTTPError, e:
                complain('Sending SMS via SMSEagle %s failed: %s' 
                          % (host, str(e.code))) 
            except urllib2.URLError, e:
                complain('Sending SMS via SMSEagle %s failed: %s'
                          % (host, str(e.args)))
            else:    
                if result.startswith('OK;'):
                    MessageSent = True
                    print('SMS successfully sent via %s to %s.' % (host, to))
                    break
                else:
                    MessageSent = False
                    complain('Sending SMS via SMSEagle %s failed: %s' 
                             % (host, result.rstrip()))
            
    return



# ----------------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------------

if not 'NOTIFY_CONTACTPAGER' in environ:
    complain('Environment variable NOTIFY_CONTACTPAGER missing')
else:
    PhoneNumber = environ['NOTIFY_CONTACTPAGER']
    EagleMessage = FormatMessage()
    sendEagleSMS(PhoneNumber, EagleMessage)
