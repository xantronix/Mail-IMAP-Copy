use inc::Module::Install;

name           'Mail-IMAP-Copy';
version_from   'lib/Mail/IMAP/Copy.pm';
author         'Xan Tronix <xan@cpan.org>';
abstract       'Recursively copy an IMAP account';
license        'mit';
requires       'Mail::IMAPClient' => 0;
requires       'Mail::Dir'        => 0;

install_share  'examples';
install_script 'scripts/imapcopy';

WriteAll;
