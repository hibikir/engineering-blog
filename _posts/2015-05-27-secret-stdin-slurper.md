---
layout: post
title: "Secret STDIN Slurper"
subtitle: "The dangers of using STDIN to drive a BASH loop"
header-img: "img/mon-city_garden.jpg"
author: "David Dooling"
tags: [bash, sysadmin, tutorials]
---

[BASH](http://www.gnu.org/software/bash/) may be looked down upon by
all the programming language hipsters out there, but when you are
doing system-level tasks it can be quite convenient: it's on every
system, it has no dependencies to install, and it can be a powerful
language when used properly.

## The Setup

As mentioned in a
[previous post](http://engineering.monsanto.com/2015/05/22/jq-change-json/),
we use [AWS CloudFormation](http://aws.amazon.com/cloudformation/) to
stand up infrastructure in AWS in an automated way.  In one use case,
we create a standard environment that makes it easy to deploy
microservices as [Docker](https://www.docker.com/) containers onto an
[Auto Scaling](http://aws.amazon.com/autoscaling/) group running
[CoreOS](https://coreos.com/).  If there is a container you want to
run on every container, e.g., a log forwarder, you can simply put the
[systemd](http://www.freedesktop.org/wiki/Software/systemd/) unit
information in the
[instance User Data](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/user-data.html)
of the Auto Scaling group's Launch Configuration in
[cloud-config](https://coreos.com/docs/cluster-management/setup/cloudinit-cloud-config/)
format.

Things are a bit more tricky if you only want run a container on a
subset of the instances.  You would typically do this with a scheduler
like
[fleet](https://coreos.com/docs/launching-containers/launching/launching-containers-fleet/)
or [Mesos](http://mesos.apache.org/).  If the container is one of your
microservices, you can just configure deployment in your continuous
integration server, e.g., [Jenkins](https://jenkins-ci.org/).  If,
however, the container is more of an infrastructure service that you
only want running on a single node, something like
[Kibana](https://www.elastic.co/products/kibana) for a system
dashboard, you need to find a different way to inject that container
into your scheduler.

As a first pass, we decided to have the helper BASH script we use to
spin up and manage state of our CloudFormation stacks simply wait for
the stack creation to complete and then issue fleet commands via SSH.
Alongside the template used to create the stack, we created a file
that contained the list of unit files we wanted the script to spin up.
So if our template is called `vpc-default.json`, then we would create
a file called `vpc-default.services` with contents something like
this:

```
kibana
route-updater
reaper
```

After the stack creation was complete, the script would read this file
and issue the appropriate fleet commands over SSH on one of the nodes
in the fleet cluster.

## The Problem

One of our engineers initially coded up the solution something like
this:

{% highlight bash %}
services_file="vpc-default.services"
while read service; do
    echo "launching service: $service"
    if ! ssh service fleetctl submit $service; then
	    echo "ERROR: failed to submit service: $service"
	    return 1
	fi
    if ! ssh service fleetctl start $service; then
	    echo "ERROR: failed to submit service: $service"
	    return 1
    fi
	echo "successfully launched service: $service"
done < "$services_file"
{% endhighlight %}

After setting the value of the variable `services_file` to the name of
the services file (in the actual script this is done dynamically), the
execution enters a `while` loop.  Each time through the `while` loop,
it `read`'s a line from STDIN and puts what is read into the variable
`service`.  But we don't want the values read from `STDIN`, we want
them read from the file, so we redirect `STDIN` to come from
`$services_file`, that's the `< "$services_file"` on the last line.

Unfortunately, this doesn't work.  When we run the script on a file
with the contents show above, all we get is:

```
launching service: kibana
successfully launched service: kibana
```

The loop only executes one time instead of three!?!  What is going on?
Why is the loop terminating early and/or what happens to the second
and third line of the file?

To try to figure this out, let's simplify the script.  Let's just echo
the each line as we read it:

{% highlight bash %}
services_file="vpc-default.services"
while read service; do
    echo "service:$service"
done < "$services_file"
{% endhighlight %}

When we run this, we get:

```
service:kibana
service:route-updater
service:reaper
```

as expected.  Something must be going wrong inside our original loop,
but what could it be?  We know running `echo` is OK, so the problem
must be with the SSH fleet commands.  Somehow, they are causing the
loop to exit without processing the last two lines of the file.  So
either they are making reading the second line evaluate to false,
which seems unlikely, or those commands are somehow consuming the
contents of `STDIN` themselves.  We can see if the latter is a possibility
by replacing the SSH commands with a simpler command that consumes
`STDIN`, `cat`:

{% highlight bash %}
services_file="vpc-default.services"
while read service; do
    echo "service:$service"
    cat
done < "$services_file"
{% endhighlight %}

When you run the above bit of code, the output is:

```
service:kibana
route-updater
reaper
```

Ah-ha! The `while` loop `read` gobbles up the the first line of the
file, but then the `cat` within the loop consumes the rest of the file
and the next time through the loop, `read` returns false and the
script moves along.  But does the same thing happens with SSH?  We can
try that too:

{% highlight bash %}
services_file="vpc-default.services"
while read service; do
    echo "ssh service:$service"
    ssh service cat
done < "$services_file"
{% endhighlight %}

Running this outputs:

```
ssh service:kibana
route-updater
reaper
```

So SSH is indeed consuming the contents of `STDIN`.  How?  Basically,
SSH connects the `STDIN` of the calling process to the `STDIN` of the
process on the remote machine so you can do cool things like pipe
stuff over SSH.  If the remote process does something with `STDIN`,
like `cat` above, great.  If it just ignores `STDIN` like the fleet
commands, then lines two through the end of the file get lost
somewhere on the remote machine.

## The Solution

The solution to this problem is quite simple and good advice whenever
writing loops in BASH: read the contents of the file into a variable
before the loop ever executes and use a `for` loop instead of a
`while` loop.  This looks something like:

{% highlight bash %}
services_file="vpc-default.services"
services=$(< "$services_file")
for service in $services; do
    echo "launching service: $service"
    if ! ssh service fleetctl submit $service; then
        echo "ERROR: failed to submit service: $service"
        return 1
    fi
    if ! ssh service fleetctl start $service; then
        echo "ERROR: failed to submit service: $service"
        return 1
    fi
    echo "successfully launched service: $service"
done
{% endhighlight %}

When you run this, you get the expected output:

```
launching service: kibana
successfully launched service: kibana
launching service: route-updater
successfully launched service: route-updater
launching service: reaper
successfully launched service: reaper
```

Then, fleet will make sure your services are running and all is right
with the world.  What happens if you need to read a very large file
where the act of doing so will cause harm to the normal operations of
your computer?  That's left as an exercise for the reader.
