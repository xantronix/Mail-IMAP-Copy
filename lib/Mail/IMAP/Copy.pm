package Mail::IMAP::Copy;

use strict;
use warnings;

BEGIN {
    use Exporter ();
    use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

    $VERSION = '0.01';
    @ISA     = qw(Exporter);

    @EXPORT      = ();
    @EXPORT_OK   = ();
    %EXPORT_TAGS = ();
}

sub new_session {
    my ( $class, %args ) = @_;

    die('No IMAP session object provided') unless defined $args{'imap'};
    die('No Maildir object provided')      unless defined $args{'maildir'};

    return bless {
        'maildir' => $args{'maildir'},
        'imap'    => $args{'imap'}
    }, $class;
}

sub maildir_flags {
    my (@imap_flags) = @_;
    my $ret = '';

    my %MAILDIR_FLAGS = (
        '$Forwarded' => 'F',
        '\Answered'  => 'R',
        '\Flagged'   => 'F',
        '\Draft'     => 'D',
        '\Deleted'   => 'T',
        '\Seen'      => 'S'
    );

    foreach my $imap_flag (@imap_flags) {
        my $maildir_flag = $MAILDIR_FLAGS{$imap_flag};
        next unless $maildir_flag;
        $ret .= $MAILDIR_FLAGS{$imap_flag};
    }

    return $ret;
}

sub convert_timestamp {
    my ($timestamp) = @_;

    my $month = 1;
    my %MONTHS = map { $_ => $month++ } qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);

    #
    # This operation will discard the timezone offset information, which is
    # something that should not vary in the representation of the timestamp
    # given by the IMAP servers.
    #
    my @match = ( $timestamp =~ /^(\d+)-(\S+)-(\d+) (\d+):(\d+):(\d+) -(?:\d+)$/ );

    return unless @match;
    return sprintf( "%04d%02d%02d %02d:%02d:%02d", $match[2], $MONTHS{ $match[1] }, $match[0], @match[ 3 .. 5 ] );
}

sub copy_message {
    my ( $self, $message ) = @_;
    my $imap    = $self->{'imap'};
    my $maildir = $self->{'maildir'};

    my @imap_flags    = $imap->flags($message);
    my $maildir_flags = maildir_flags(@imap_flags);

    my $delivery = $maildir->deliver(
        sub {
            my ($fh) = @_;

            $imap->message_to_file( $fh, $message );
        }
    );

    if ( $maildir_flags || grep { $_ =~ /old/i } @imap_flags ) {
        $delivery->mark($maildir_flags);
    }

    return $delivery;
}

sub copy_mailboxes {
    my ( $self, %opts ) = @_;

    my $maildir = $self->{'maildir'};
    my $imap    = $self->{'imap'};

    my @mailboxes = $imap->folders;

    foreach my $mailbox (@mailboxes) {
        unless ( $maildir->mailbox_exists($mailbox) ) {
            $maildir->create_mailbox($mailbox);
        }

        $maildir->select_mailbox($mailbox);
        $imap->select($mailbox);

        my @messages = $imap->messages;

        foreach my $message (@messages) {
            my $delivery = $self->copy_message($message);

            $opts{'callback'}->($delivery) if defined $opts{'callback'};
        }
    }
}

sub copy_subscriptions {
    my ($self) = @_;

    my $maildir = $self->{'maildir'};
    my $imap    = $self->{'imap'};

    my $file = "$maildir->{'dir'}/courierimapsubscribed";

    open( my $fh, '>', $file ) or die("Unable to open $file for writing: $!");

    foreach my $subscription ( $imap->subscribed ) {
        print {$fh} "$subscription\n";
    }

    close $fh;

    return;
}

1;
