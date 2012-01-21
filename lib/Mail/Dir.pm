package Mail::Dir;

use strict;
use warnings;

use Errno;
use IO::Handle;

use Cwd   ();
use Fcntl ();

my $MAX_BUFFER_LEN      = 4096;
my $MAX_TMP_LAST_ACCESS = 129600;
my $DEFAULT_MAILBOX     = 'INBOX';

sub dirs {
    my ($dir) = @_;

    return (
        'dir' => $dir,
        'tmp' => "$dir/tmp",
        'new' => "$dir/new",
        'cur' => "$dir/cur"
    );
}

sub open {
    my ( $class, %opts ) = @_;
    $opts{'dir'} ||= 'maildir';

    my %dirs = dirs( $opts{'dir'} );

    foreach my $key (qw(dir tmp new cur)) {
        my $dir = $dirs{$key};

        if ( $opts{'create'} ) {
            unless ( -d $dir ) {
                mkdir($dir) or die("Unable to mkdir() $dir: $!");
            }
        }
        else {
            die("Not a directory: $!") unless -d $dir;
        }
    }

    chomp( my $hostname = `hostname` );

    return bless {
        'dir'             => $opts{'dir'},
        'with_extensions' => $opts{'with_extensions'} ? 1 : 0,
        'hostname'        => $hostname,
        'mailbox'         => $DEFAULT_MAILBOX,
        'deliveries'      => 0
    }, $class;
}

sub mailbox_dir {
    my ( $self, $mailbox ) = @_;
    $mailbox ||= $self->mailbox;

    my @components = split /\./, $mailbox;
    shift @components;

    my $subdir = join( '/', map { ".$_" } @components );

    return "$self->{'dir'}/$subdir";
}

sub select_mailbox {
    my ( $self, $mailbox ) = @_;

    die('Maildir++ extensions not enabled') unless $self->{'with_extensions'};
    die('Invalid mailbox name')             unless $mailbox =~ /^$DEFAULT_MAILBOX(?:\..*)*$/;
    die('Mailbox does not exist')           unless -d $self->mailbox_dir($mailbox);

    return $self->{'mailbox'} = $mailbox;
}

sub mailbox {
    my ($self) = @_;

    return $self->{'mailbox'};
}

sub mailbox_exists {
    my ( $self, $mailbox ) = @_;

    return -d $self->mailbox_dir($mailbox);
}

sub create_mailbox {
    my ( $self, $mailbox ) = @_;

    die('Maildir++ extensions not enabled') unless $self->{'with_extensions'};

    my %dirs = dirs( $self->mailbox_dir($mailbox) );

    foreach my $key (qw(dir tmp new cur)) {
        my $dir = $dirs{$key};

        mkdir($dir) or die("Unable to mkdir() $dir: $!");
    }

    return 1;
}

sub name {
    my ( $self, %args ) = @_;

    my $file = $args{'file'} or die('No message file or handle specified');
    my $time = $args{'time'} ? $args{'time'} : time();

    my $name = sprintf( "%d.%d.%s", $time, $$, $self->{'hostname'} );

    if ( $self->{'with_extensions'} ) {
        my $size;

        if ( defined $args{'size'} ) {
            $size = $args{'size'};
        }
        elsif ( !ref($file) ) {
            my @st = stat($file) or die("Unable to stat() $file: $!");
            $size = $st[7];
        }

        if ( defined $size ) {
            $name .= sprintf( ",%d", $size );
        }
    }

    return $name;
}

sub spool {
    my ( $self, %args ) = @_;

    my $size = 0;

    my $from = $args{'from'} or die('No message file or handle specified to spool from');
    my $to   = $args{'to'}   or die('No message file specified to spool to');

    my $fh_from;

    if ( ref($from) eq 'GLOB' ) {
        $fh_from = $from;
    }
    else {
        sysopen( $fh_from, $from, &Fcntl::O_RDONLY ) or die("Unable to open $from for reading: $!");
    }

    sysopen( my $fh_to, $to, &Fcntl::O_CREAT | &Fcntl::O_WRONLY ) or die("Unable to open $to for writing: $!");

    while ( my $len = $fh_from->read( my $buf, $MAX_BUFFER_LEN ) ) {
        $size += syswrite( $fh_to, $buf, $len );

        $fh_to->flush;
        $fh_to->sync;
    }

    close $fh_to;
    close $fh_from unless ref($from) eq 'GLOB';

    return $size;
}

sub deliver {
    my ( $self, $file ) = @_;

    my $oldcwd = Cwd::getcwd() or die("Unable to getcwd(): $!");
    my $dir    = $self->mailbox_dir;
    my $time   = time();

    my $name = $self->name(
        'file' => $file,
        'time' => $time
    );

    chdir($dir) or die("Unable to chdir() to $dir: $!");

    my $file_tmp = "tmp/$name";

    return if -e $file_tmp;

    my $size = $self->spool(
        'from' => $file,
        'to'   => $file_tmp
    );

    my $name_new = $self->name(
        'file' => $file_tmp,
        'time' => $time,
        'size' => $size
    );

    my $file_new = "new/$name_new";

    unless ( rename( $file_tmp, $file_new ) ) {
        die("Unable to deliver incoming message to $file_new: $!");
    }

    chdir($oldcwd) or die("Unable to chdir() to $oldcwd: $!");

    $self->{'deliveries'}++;

    return {
        'mailbox' => $self->{'mailbox'},
        'file'    => "$dir/$file_new",
        'name'    => $name_new,
        'size'    => $size
    };
}

sub messages {
    my ($self, %opts) = @_;
    my @ret;

    my $dir = $self->mailbox_dir;

    foreach my $key ( qw(new cur) ) {
        next unless $opts{$key};

        my $path = "$dir/$key";

        opendir( my $dh, $path ) or die("Unable to opendir() $path: $!");

        while ( my $item = readdir($dh) ) {
            next if $item =~ /^\./;

            my $file = "$path/$item";
            my $size;

            if ( $self->{'with_extensions'} ) {
                $size = $1 if $item =~ /,(\d+)$/;
            }

            unless ( defined $size ) {
                $size = ( stat $file )[7] or die("Unable to stat() $file: $!");
            }

            my $message = {
                'mailbox' => $self->{'mailbox'},
                'file'    => $file,
                'name'    => $item,
                'size'    => $size
            };

            if ( defined $opts{'filter'} ) {
                next unless $opts{'filter'}->($message);
            }

            push @ret, $message;
        }

        closedir $dh;
    }

    return \@ret;
}

sub purge {
    my ($self) = @_;
    my @ret;

    my $time = time();
    my $dir  = $self->mailbox_dir;
    my $path = "$dir/tmp";

    opendir( my $dh, $path ) or die("Unable to opendir() $dir: $!");

    while ( my $item = readdir($dh) ) {
        next if $item =~ /^\./;

        my $file = "$path/$item";
        my @st   = stat($file) or die("Unable to stat() $file: $!");

        next unless $time - $st[8] > $MAX_TMP_LAST_ACCESS;

        unlink($file) or die("Unable to unlink() $file: $!");

        push @ret, {
            'mailbox' => $self->{'mailbox'},
            'file'    => $file,
            'name'    => $item,
            'size'    => $st[7]
        };
    }

    closedir $dh;

    return \@ret;
}

1;
