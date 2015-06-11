package core;

use strict;
use Irssi;

our $VERSION;

our $CMD_SYNTAX = qr/^\w{1,20}$/;
my %MODULES; # Keep track of loaded modules.
my %CORE_MODULES; # Disallow unload/reload of core modules.

sub init
{
    print "Initialized";
}

# === Module Management =======================================================
sub module
{
    my $name = lc shift @_;
    return exists $MODULES{$name} ? $MODULES{$name} : undef;
}

sub load_module
{
    my ($name) = @_;
    my $path = Irssi::settings_get_str('trigger_module_path') . $name . '.pm';
    die "Module `$name` already loaded.\n" if (exists $INC{$path});
    eval
    {
        require $path;
        my $module = _();
        $MODULES{$name} = $module;
        $module->{init}();
        return "Module `$name` loaded.";
    }
    or do
    {
        my $e = $@;
        die "Module `$name` does not exist.\n";
    }
}

sub unload_module
{
    my ($name) = @_;
    return "Cannot unload core module `$name`." if  exists $CORE_MODULES{$name};
    my $path = Irssi::settings_get_str('trigger_module_path') . $name . '.pm';
    return "Module `$name` is not loaded." unless exists $INC{$path};
    eval { $MODULES{$name}{'deinit'}() if exists $MODULES{$name} && exists $MODULES{$name}{'deinit'} } or do {}; # Continue even if deinit fails. TODO: Log.
    delete $MODULES{$name};
    delete $INC{$path};
    return "Module `$name` unloaded.";
}

sub reload_module
{
    my ($name) = @_;
    return "Cannot unload core module `$name`." if  exists $CORE_MODULES{$name};
    unload_module($name);
    load_module($name);
    return "Module `$name` reloaded.";
}

# === Core modules ========================================================
my $m_on = {
    name => 'on',
    run => sub
    {
        Irssi::settings_set_bool('trigger_active', 1);
        return 'Enabled Trigger';
    },
    help    => 'Enables the trigger mechanism. Requires access.',
    version => $VERSION,
    core    => 1,
    access  => 100
};
my $m_off = {
    name => 'off',
    run => sub
    {
        #Irssi::settings_set_bool('trigger_active', 0);
        return 'off => I can\'t let you do that (Orez|Mithorium)';
    },
    help    => 'Disables the trigger mechanism. Requires access.',
    version => $VERSION,
    core    => 1,
    access  => 100
};
my $m_load = {
    name => 'load',
    run => sub
    {
        $_ = lc shift;
        return unless ($_ && $_ =~ /$CMD_SYNTAX/);
        eval
        {
            return load_module($_);
        }
        or do
        {
            chomp $@;
            return $@;
        }
    },
    help    => 'Loads a module by name. Requires access.',
    version => $VERSION,
    core    => 1,
    access  => 100
};
my $m_unload = {
    name => 'unload',
    run => sub
    {
        $_ = lc shift;
        return unless ($_ && $_ =~ /$CMD_SYNTAX/);
        eval { return unload_module($_); } or do
        {
            chomp $@;
            return $@;
        }
    },
    help    => 'Unloads the specified module. Requires access.',
    version => $VERSION,
    core    => 1,
    access  => 100
};
my $m_reload = {
    name => 'reload',
    run => sub
    {
        $_ = lc shift;
        return if ($_ && $_ !=~ /$CMD_SYNTAX/);
        if (!$_)
        {
            # TODO: Reload all modules
            return;
        }
        eval { return reload_module($_); } or do
        {
            chomp $@;
            return $@;
        }
    },
    help    => 'Reloads the specified module. Requires access.',
    version => $VERSION,
    core    => 1,
    access  => 100
};
my $m_help = {
    name => 'help',
    run => sub
    {
        $_ = lc shift;

        return if ($_ && $_ !~ /$CMD_SYNTAX/);
        unless ($_)
        {
            my $reply = 'help <command> for details:';
            foreach my $k (keys %MODULES)
            {
                $reply = $reply . " $k";
            }
            return $reply;
        }

        return "$_: " . $MODULES{$_}{'help'} if (exists $MODULES{$_});
        return "$_: module does not exist.";
    },
    help    => 'Displays help messages for various commands.',
    version => $VERSION,
    core    => 1,
    access  => 0
};
my $m_version = {
    name => 'version',
    run => sub
    {
        $_ = lc shift;
        return "trigger.pl: version $VERSION" unless ($_);
        return "$_: module does not exist." unless (exists $MODULES{$_});
        return "$_: version " . $MODULES{$_}{'version'};
    },
    help    => 'Returns the version number of a given module.',
    version => $VERSION,
    core    => 1,
    access  => 0
};
# -----------------------------------------------------------------------------
%MODULES = (
    on      => $m_on,
    off     => $m_off,
    load    => $m_load,
    unload  => $m_unload,
    reload  => $m_reload,
    help    => $m_help,
    version => $m_version
);
# TODO: DRY this up.
%CORE_MODULES = (on => 1, off => 1, load => 1, unload => 1, reload => 1, help => 1, version => 1);

1;
