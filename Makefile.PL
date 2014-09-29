use inc::Module::Install;

name           'Mail-IMAP-Copy';
version_from   'lib/Mail/IMAP/Copy.pm';
author         'Erin Schoenhals <erin@cpanel.net>';
abstract       'Recursively copy an IMAP account';
license        'perl';
requires       'Mail::IMAPClient' => 0;

install_share  'examples';
install_script 'scripts/imapcopy';

WriteAll;
