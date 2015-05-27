# trigger - irssi 0.8.5
# Copyright (c) 2011 Alexandre <alex@segfault.me> Beaulieu
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
# CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
# TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

use strict;
use Irssi;

our ($VERSION, %IRSSI);
my $SCRIPT_FOLDER = "~/.irssi/scripts/";

# --- Settings ---
$VERSION = "1.0"; # M.m.S
%IRSSI = (
            name        => 'trigger.pl',
            authors     => 'Alexandre Beaulieu',
            contact     => 'alex@segfault.me',
            url         => 'http://github.com/irssi/trigger.pl',
            license     => 'MIT',
            description => 'Provides a bot-like trigger that allows modules to be loaded dynamically.'
         );
Irssi::settings_add_bool('trigger', 'trigger_active', 0);
Irssi::settings_add_bool('trigger', 'trigger_debug', 0);
Irssi::settings_add_str('trigger', 'trigger_trigger', '%');
Irssi::settings_add_str('trigger', 'trigger_active_channels', '');
Irssi::settings_add_str('trigger', 'trigger_module_path', 'trigger/');
Irssi::settings_add_str('trigger', 'trigger_module_autoload_path', 'trigger/autoload');

Irssi::theme_register([ 'trigger_crap', '{hilight ' .
                        $IRSSI{'name'} . '}: $0']);

# === Built-in Modules ========================================================
my %MODULES;
my $m_on = {
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
             run => sub
                        {
                            Irssi::settings_set_bool('trigger_active', 0);
                            return 'Disabled Trigger';
                        },
             help    => 'Disables the trigger mechanism. Requires access.',
             version => $VERSION,
             core    => 1,
             access  => 100
            };
my $m_load = {
              run => sub
                         {
                             $_ = lc shift;
                             return "$_: module is already loaded. Use reload to reload it." if (exists $INC{$_.'.pm'});
                         },
              help    => 'Loads a module by name. Requires access.',
              version => $VERSION,
              core    => 1,
              access  => 100
            };
my $m_unload = {
                run => sub
                           {
                           },
                help    => 'Unloads the specified module. Requires access.',
                version => $VERSION,
                core    => 1,
                access  => 100
               };
my $m_reload = {
                run => sub
                           {
                               $_ = lc shift;
                               return "$_: module does not exist." unless (exists $MODULES{$_});
                               print "Reloading module ($_)" if (Irssi::settings_get_bool('trigger_debug'));
                               # This is where we do the black magic module reloading hacks.
                           },
                help    => 'Reloads the specified module. Requires access.',
                version => $VERSION,
                core    => 1,
                access  => 100
               };
my $m_help = {
              run => sub
                         {
                             $_ = lc shift;
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
%MODULES = (    # Just manually load the core.
                on      => $m_on,
                off     => $m_off,
                load    => $m_load,
                unload  => $m_unload,
                reload  => $m_reload,
                help    => $m_help,
                version => $m_version
           );
# -----------------------------------------------------------------------------

# === Internal Callbacks ======================================================
# Called when a message is received.
sub trigger_msg
{
    my ($server, $msg, $nick, $addr, $target) = @_;
    return unless (Irssi::settings_get_bool('trigger_active')); # Trigger must be enabled.
    my @channels = split (/ /, Irssi::settings_get_str('trigger_active_channels'));
    return unless (grep {/$target/} @channels); # Must be in a query or active channel.
    my $trigger = Irssi::settings_get_str('trigger_trigger');
    trigger_dispatch($1, $msg, $nick, ($target eq undef) ? $nick : $target, $server) if ($msg =~ s/^$trigger(\w*)\b ?//);
}
Irssi::signal_add('message public', 'trigger_msg');
Irssi::signal_add('message private', 'trigger_msg');

# === Command hooks ===========================================================
# Usage: /TRIGGER [command [arg1 [arg2 [...] ] ]
sub cmd_trigger
{
    my ($data, $server, $witem) = @_;
    my @args = split / /, $data;
    unless (@args)
    {
        my $msg = 'currently' . (Irssi::settings_get_bool('trigger_active') ? '' : ' not') . ' enabled';
        if ($witem)
        {
            my $window = $witem->window();
            $window->printformat(MSGLEVEL_CLIENTCRAP, 'trigger_crap', $msg);
        }
        else
        {
            Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'trigger_crap', $msg);
        }
        return;
    }
    $_ = lc shift @args;
    my $cmd_args = (@args) ? join ' ', @args : undef;
    trigger_dispatch($_, $cmd_args, $server->{nick}, undef, $server);
}
Irssi::command_bind('trigger', 'cmd_trigger');

# === Command Handler =========================================================
# Dispatch a command to the proper command handler.
sub trigger_dispatch
{
    my ($module, $args, $nick, $target, $server) = @_;
    return unless (exists $MODULES{lc $module});
    my @command = ($module, $args, $nick, $target, $server);
    Irssi::timeout_add_once(10, "handle_command", \@command);
}

# Executes a command
sub handle_command
{
    my ($cmd, $args, $nick, $target, $server) =  @{$_[0]};
    return unless (exists $MODULES{lc $cmd}); # Ignore non-existing commands.
    my $data = $MODULES{lc $cmd}{'run'}($args);
    Irssi::printformat(MSGLEVEL_CRAP, 'trigger_crap', "handle_command <$nick> $cmd($args) -> $target\n>> $data") if (Irssi::settings_get_bool('trigger_debug'));
    $server->command("MSG $target $data") if ($target && $data);
    # TODO: If the command is run via /trigger, print the output in the current window for convenience.
}