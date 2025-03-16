# Extending OOD With Initializers

## Table of Contents

Live tutorial steps as created for the Global OOD Conference 2025

- [Base OOD Tutorial](../../../../ubccr/hpc-toolset-tutorial/ondemand)
- [Getting User Information](#getting-user-info)
- [Canceling Jobs](#canceling-jobs)

This tutorial will be using the the `hpcadmin` credentials listed in
[Accessing the Applications](ubccr/hpc-toolset-tutorial/docs/applications.md).

## External links

- [Online Documentation](https://osc.github.io/ood-documentation/master/)
- [Jupyter Install Tutorial](https://osc.github.io/ood-documentation/latest/tutorials/tutorials-interactive-apps/add-jupyter.html)

## Getting User Information

User information is stored in a number of places, i.e. ColdFront, Slurm DB, Lustre/Vast/NFS/etc
storage locations. Each of these are generally query-able, and this information can be added into
OOD for making the user's interactions simpler, streamlining the submission and cluster 
interactions to maximize the time spent doing research.

To this end, initializers are a powerful tool. an example initializers file with reasonably 
generic information queries is provided in [initializers-example.rb](initializers-example.rb)

We will use slurm accounts as the primary example, as the toolset uses slurm as its job
scheduler, and as such there's plenty of information we can retrieve using slurm's commands, i.e.


```shell
/usr/bin/sacctmgr show association where user=$USER format=Account --parsable2 --noheader"
```

With a command that retrieves information, we can utilize ruby and the dashboard loading mechanism
in OOD to get this information into a place where OOD can use it. i.e.

```shell
# /etc/ood/config/apps/dashboard/initializers/init.rb

require 'open3'

class CustomAccounts
  def self.accounts
    @account ||= begin
      sinfo_cmd = "/usr/bin/sacctmgr show association where user=$USER format=Account --parsable2 --noheader"
      @accounts_avail = []
      o, e, s = Open3.capture3(sinfo_cmd)
      o.each_line do |v|
        @accounts_avail.append(v.strip)
      end
      @accounts_avail
    end
    @accounts_avail
  end
end

CustomAccounts.accounts
```

With this in place, restart the OOD Web Server, and you'll notice nothing has changed. At least on the surface.

Now we can update a different file. We'll go back to the jupyter application from earlier and tinker with it. First, we will change the form name to match the submit form, making it an embedded ruby file.The .erb file extension indicates this is embedded ruby file. This means that Ruby will template this file and turn it into a yml file that OnDemand will then read.  `<%=` and `%>` are embedded ruby tags to turn the variable (or expression) into a string.

```shell
mv form.yml form.yml.erb
```
This change enables using ruby syntax in the form, 

```shell
# /home/hpcadmin/ondemand/dev/apps/jupyter/form.yml.erb

  custom_account:
    label: "Account (--account=value)"
    required: true
    widget: select
    options:
      <%- CustomAccounts.accounts.each do |a| %>
      - [ "<%= a.strip %>", "<%= a %>" ]
      <%- end -%>
    cacheable: false

  # comment out bc_account
  #- bc_account
  - custom_account
```

And we'll need to enable this in submit.yml.erb as well:
```shell
# /home/hpcadmin/ondemand/dev/apps/jupyter/submit.yml.erb

script:
  native:
    <% if !custom_account.blank? %>
    - "-A"                                                                                                - "<%= custom_account %>"                                                                             <% end %>  
```
and P.S. we should update that debug partition clause in form.ymml.erb as well:

```shell
# /home/hpcadmin/ondemand/dev/apps/jupyter/form.yml.erb

          data-set-custom-account: 'staff',
          data-hide-custom-account: true,
```
Well, now you can delete all those jobs that might still be running. But as soon as you do, they're gone forever, including the submission information. Some of that should be kept around, in case we need to dig back through it.

## Canceling Jobs

This is super simple, but should go in your config folder, in case it's moved

```shell
# /etc/ood/config/ondemand.d/slurm_cancel.yml

cancel_session_enabled: 'true'
```

And now we can cancel jobs without removing the session cards. 

## More Initializer Functions

User accounts aren't the only thing we can pull into OOD via initializers. Imagine a scenario where your site has acquired new hardware for a pre-existing cluster. This hardware will likely be defined differently in slurm, so that it's identifiable to both the sysadmin and the user. The most common way of doing this is by creating a new partition for the new hardware.

For this tutorial, we won't add another image, but we will demonstrate how the hardcoded compute and debug partitions can instead be auto-populated by asking slurm. This reduces the number of forms we have to update in OOD. 

```shell
sinfo --noheader --exact --all -o %R
```

and added to the initializer
```shell 
# /etc/ood/config/apps/dashboard/initializers/init.rb

class CustomPartitions
  def self.partitions
    @partitions ||= begin
      sinfo_cmd = "/usr/bin/sinfo"
      args = ["--noheader","--exact","--all","-o %R"]
      @partitions_avail = []
      o, e, s = Open3.capture3(sinfo_cmd , *args)
      o.each_line do |v|
        @partitions_avail.append(v.strip)
      end
      @partitions_avail
    end
  end
end

CustomPartitions.partitions
```

Also of note, we passed args as an array to the command this time. User preference on making it a single line or using ruby to pass arguments. Now in our form

```shell
# /home/hpcadmin/ondemand/dev/apps/jupyter/form.yml.erb

  custom_partition:
    label: "Partition (--partition=value)"
    required: true
    widget: select
    options:
      <%- CustomPartitions.partitions.each do |a| %>
      - [ "<%= a.strip %>", "<%= a %>" ]
      <%- end -%>
    cacheable: false

  #comment out
  #- custom_queue
  - custom_partition
```

At this point, we'll remove "custom queue" and endeavor to stick with partitions, to make the SchedMD team happy. Our end users may not like it, but they'll get used to it. 

We should also update the submit.yml.erb, just to make sure our submissions are appropriately made

```shell
# /home/hpcadmin/ondemand/dev/apps/jupyter/submit.yml.erb

    - "-partition"
    - "<%= custom_partition %>" 
```

## Dev Dashboard Too?

Yes, the initializers can be put in the dev dashboard instead of the sitewide config.

```shell
# /home/hpcadmin/ondemand/dev/dashboard/config/initializers/init.rb

require 'open3'

class CustomAccounts
  def self.accounts
    @account ||= begin

...
```
I'd recommend copying the sitewide to the dev dashboard before getting too crazy.

```shell
cp  /etc/ood/config/apps/dashboard/initializers/init.rb  /home/hpcadmin/ondemand/dev/dashboard/config/initializers/init.rb
```
