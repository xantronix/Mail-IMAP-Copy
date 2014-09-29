# NAME

imapcopy - Recursively download an IMAP account

# SYNOPSIS

    ~$ imapcopy --config remote.conf

# DESCRIPTION

imapcopy will download the entire contents of an IMAP account, recursively, into
a Maildir++ directory structure of the user's choosing, based on the values
listed in a configuration file given.  Mail can be delivered into an existing
Maildir++ directory structure, though currently this will result in duplication.

# ARGUMENTS

- __--config__ _file_

    List the location of a mandatory configuration file.  This file will contain
    plaintext credentials, so it should have permissions only allowing the user to
    access its contents.

# CONFIGURATION FILE

## SYNTAX

The `imapcopy` configuration file is of a simple format.  Empty lines, or lines
consisting of only whitespace, will be ignored.  As well, lines beginning with
any amount of whitespace, followed by a comment delimited by the __`#`__
character, shall also be ignored.

Configuration options are specified in the following form, always with double
quotes:

    option_name "value"

Any amount of whitespace may proceed or follow `option_name` or "_value_".  A
comment may follow a configuration option statement on the same line, such as:

    foo "bar" # comment!

Unescaped double quotes may unambiguously be used within a value field.

## VALID OPTIONS

### Local mail delivery

These options specify the manner in which messages from the remote IMAP service
are delivered to the local machine.

- `maildir`

    Specifies a path to a directory that may or may not exist that shall be used as
    a Maildir++ directory to which messages are delivered.

### Remote IMAP account

These options specify the connection details and authentication credentials of
the remote IMAP service and account.

- `username`

    The remote IMAP account username.

- `password`

    The plaintext password of the remote IMAP account.

- `host`

    The hostname or Internet address of the remote IMAP service.

- `port`

    A numerical value indicating the port number of the remote IMAP service.

- `ssl`

    Specifies whether or not the IMAP client should use SSL for the IMAP session.
    Must be set to `on` or `off`.  Note that this is not typically appropriate
    for use over standard IMAP port 143.

- `tls`

    Specifies whether or not the IMAP client should negotiate to use TLS for the
    IMAP session.  Must be set to `on` or `off`.  This may be appropriate for use
    over the standard IMAP port 143, if the remote IMAP service supports it.

### Remote IMAP service behavior

These options affect the behavior of the remote IMAP service.

- `peek`

    Specifies whether or not the IMAP client should update any flags when fetching
    message data.  Must be set to `on` or `off`.  When set to `on`, the IMAP
    service will not update any flags when message data is requested.  When set to
    `off`, the IMAP service will set messages as __Seen__ when retrieving.

# AUTHOR

Xan Tronix <xan@cpan.org>

# COPYRIGHT

Copyright (c) 2014, cPanel, Inc.  Distributed under the terms of the MIT
license.
