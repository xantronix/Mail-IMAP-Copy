package Mail::Dir::Message;

use strict;
use warnings;

use File::Basename ();

sub from_file {
    my ( $class, %args ) = @_;

    die('No maildir object specified')           unless defined $args{'maildir'};
    die('maildir object is of incorrect type')   unless ref( $args{'maildir'} ) eq 'Mail::Dir';
    die('No mailbox specified')                  unless defined $args{'mailbox'};
    die('No message filename specified')         unless defined $args{'file'};
    die('No message name specified')             unless defined $args{'name'};
    die('No stat() object provided for message') unless defined $args{'st'};
    die('stat() object is not an ARRAY')         unless ref( $args{'st'} ) eq 'ARRAY';

    if ( defined $args{'dir'} ) {
        die('"dir" may only specify "tmp", "new" or "cur"') unless $args{'dir'} =~ /^(?:tmp|new|cur)$/;
    }

    my $flags = '';

    if ( $args{'flags'} ) {
        $flags = parse_flags( $args{'flags'} );
    }
    elsif ( $args{'name'} =~ /:(?:1,.*)2,(.*)$/ ) {
        $flags = parse_flags($1);
    }

    return bless {
        'maildir' => $args{'maildir'},
        'mailbox' => $args{'mailbox'},
        'dir'     => $args{'dir'},
        'file'    => $args{'file'},
        'name'    => $args{'name'},
        'size'    => $args{'st'}->[7],
        'atime'   => $args{'st'}->[8],
        'mtime'   => $args{'st'}->[9],
        'ctime'   => $args{'st'}->[10],
        'flags'   => $flags
    }, $class;
}

sub parse_flags {
    my ($flags) = @_;
    my $ret = '';

    die('Invalid flags') unless $flags =~ /^[PRSTDF]*$/;

    foreach my $flag (qw(D F P R S T)) {
        $ret .= $flag if index( $flags, $flag ) >= 0;
    }

    return $ret;
}

sub mark {
    my ( $self, $flags ) = @_;
    $flags = parse_flags($flags);

    my $mailbox_dir = $self->{'maildir'}->mailbox_dir( $self->{'mailbox'} );
    my $new_file    = "$mailbox_dir/cur/$self->{'name'}:2,$flags";

    unless ( rename( $self->{'file'}, $new_file ) ) {
        die("Unable to rename() $self->{'file'} to $new_file: $!");
    }

    $self->{'file'}  = $new_file;
    $self->{'flags'} = $flags;

    return $self;
}

sub move {
    my ( $self, $mailbox ) = @_;

    die('Maildir++ extensions not supported') unless $self->{'maildir'}->{'with_extensions'};
    die('Specified mailbox is same as current mailbox') if $mailbox eq $self->{'maildir'}->{'mailbox'};

    my $mailbox_dir = $self->{'maildir'}->mailbox_dir($mailbox);
    my $new_file    = "$mailbox_dir/cur/$self->{'name'}:2,$self->{'flags'}";

    unless ( rename( $self->{'file'}, $new_file ) ) {
        die("Unable to rename() $self->{'file'} to $new_file: $!");
    }

    $self->{'file'} = $new_file;

    return $self;
}

sub passed {
    shift->{'flags'} =~ /P/;
}

sub replied {
    shift->{'flags'} =~ /R/;
}

sub seen {
    shift->{'flags'} =~ /S/;
}

sub trashed {
    shift->{'flags'} = /T/;
}

sub draft {
    shift->{'flags'} =~ /D/;
}

sub flagged {
    shift->{'flags'} =~ /F/;
}

1;
