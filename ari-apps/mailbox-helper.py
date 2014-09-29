#!/usr/bin/env python
"""A handy mailbox helper

Copyright 2014 Matt Jordan
"""

import ari
import logging
import time

logging.basicConfig(level=logging.ERROR)


def stasis_start_handler(channel_obj, ev):
    """Handler for StasisStart event"""

    channel = channel_obj.get('channel')
    args = ev.get('args')
    mailbox_id = '{0}@digium'.format(args[0])
    action = args[1]

    try:
        mailbox = client.mailboxes.get(mailboxName=mailbox_id)
    except:
        client.mailboxes.update(mailboxName=mailbox_id, oldMessages=0, newMessages=0)
        mailbox = client.mailboxes.get(mailboxName=mailbox_id)

    if action == 'reset':
        mailbox.update(oldMessages=0, newMessages=0)
        print 'Mailbox {0} has been reset'.format(mailbox_id)
    elif action == 'increment':
        new_count = mailbox.json['new_messages'] + 1
        mailbox.update(oldMessages=0, newMessages=new_count)
        print 'Mailbox count for {0} is now {1}'.format(mailbox_id, new_count)
    else:
        print 'Unknown action: {0}'.format(action)

    channel.continueInDialplan()


while True:
    try:
        client = ari.connect('http://localhost:8088', 'asterisk', 'asterisk')
        client.on_channel_event('StasisStart', stasis_start_handler)
        client.run(apps='mailbox-helper')
    except:
        print "Shazbot!"
        time.sleep(1)


