package App::IMAP::Copy;

use strict;
use warnings;

use Mail::Dir                ();
use Mail::IMAP::Copy         ();
use Mail::IMAP::Copy::Config ();
use Mail::IMAPClient         ();

use Getopt::Long ('GetOptionsFromArray');

sub usage {
    my ($message) = @_;

    print STDERR "$message\n" if $message;
    print "usage: $0 --config file\n";

    exit 1;
}

sub run {
    my ( $class, @args ) = @_;
    my %opts;

    GetOptionsFromArray(
        \@args,
        'config=s' => \$opts{'config'}
    ) or usage();

    usage('No configuration file specified') unless $opts{'config'};

    my $config = Mail::IMAP::Copy::Config->load( $opts{'config'} );

    die('No username specified')     unless defined $config->{'username'};
    die('No password specified')     unless defined $config->{'password'};
    die('No host specified')         unless defined $config->{'host'};
    die('No maildir path specified') unless defined $config->{'maildir'};
    die('SSL and TLS cannot both be enabled') if $config->{'ssl'} && $config->{'tls'};

    $config->{'maildir'} =~ s/^~/$ENV{'HOME'}/ if defined $ENV{'HOME'};

    my %imap_settings = (
        'Server'   => $config->{'host'},
        'User'     => $config->{'username'},
        'Password' => $config->{'password'},
        'Ssl'      => defined $config->{'ssl'} && $config->{'ssl'} eq 'on',
        'Tls'      => defined $config->{'tls'} && $config->{'tls'} eq 'on',
        'Peek'     => defined $config->{'peek'} && $config->{'peek'} eq 'on',
        'Uid'      => 1,
    );

    my %maildir_settings = (
        'dir'             => $config->{'maildir'},
        'create'          => 1,
        'with_extensions' => 1
    );

    my $imap    = Mail::IMAPClient->new(%imap_settings);
    my $maildir = Mail::Dir->open(%maildir_settings);

    my $session = Mail::IMAP::Copy->new_session(
        'maildir' => $maildir,
        'imap'    => $imap
    );

    $session->copy_mailboxes(
        'callback' => sub {
            my ($delivery) = @_;

            print "Delivered $delivery->{'name'} to $delivery->{'file'}\n";
        }
    );

    $session->copy_subscriptions;

    return 0;
}

1;
