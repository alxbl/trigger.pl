# This is a example trigger.pl module skeleton.
package example;

# Define module structure
our $m =
{
    name => 'Example',
    authors => 'alxbl',
    contact => 'alex@segfault.me',
    version => '0.1',
    # depends => ['access'], # Not implemented yet.
    # --- Hooks ---
    init   => sub  # Called right after the module is loaded.
    {
        # Initialize state here.
        # die "An error occurred while initializing the module.
        $m{'state'}{'called'} = 0;
    },
    run    => sub  # Called when the command is typed in an active channel.
    {
        # args - any text that followed the command.
        # modules - a hash containing the list of loaded modules.
        # $nick - the user who called the command.
        # $target - the channel/query in which the command was called.
        # $server - the Irssi::Server object.
        my ($args, $modules, $nick, $target, $server) = @_;
        $times = ++$m{'state'}{'called'};
        return "This is an example module. Called $times time(s)."; # Anything returned will be printed to the caller.
    },
    deinit => sub  # Called right before the module unloads.
    {
        # Clean up state here.
        # Should not die() here.
        delete $m{'state'};
    },
    help => 'Prints an example.', # Called when the user queries for help.
    # You can store state directly in the hash, or in module scope.
    state => {},
};

# Called by trigger.pl to construct the module.
sub _ { return $m; }
