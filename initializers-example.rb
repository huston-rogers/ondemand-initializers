require 'open3'

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

class CustomQOS
  def self.qos
    @qos ||=begin
      sinfo_cmd = "/usr/bin/sacctmgr show QOS format=Name,MaxWall --noheader"
      @qos_avail = []
      o, e, s = Open3.capture3(sinfo_cmd)
      o.each_line do |v|
        @qos_avail.append(v.strip)
      end
      if first = @qos_avail.detect { |entry| entry.include? "ood"}
        @qos_avail.delete(first)
        @qos_avail.unshift(first)
      end
            @qos_avail
    end
    @qos_avail
  end
end

CustomQOS.qos

class DynamicOptions
  attr_reader :accounts, :qos_avail
  attr_reader :accounts, :qos_avail
  def self.options()
    @@accounts = []
    @@qos_avail = []
    @options ||=begin
      sinfo_cmd = "/usr/bin/sacctmgr show User $USER --associations format=account,qos --parsable2 --noheader"
      @qos_all = []
      o, e, s = Open3.capture3(sinfo_cmd)
      o.each_line do |v|
        full = v.split("|")
        @qos=full[1].split(",")
        @qos_all.unshift(*@qos)
        @@accounts.append(full[0].strip())
      end
      if first = @@qos_avail.detect { |entry| entry.include? "ood"}
        @@qos_avail.delete(first)
        @@qos_avail.unshift(first)
      end
      @qos_all = @qos_all.collect(&:strip)
      @qos_all = @qos_all.uniq

      @qos_all.each do |x|
        if found = CustomQOS.qos.detect { |entry| entry.include? x }
          @@qos_avail.unshift(found)
        end
      end
    end
  end
  def self.accounts
    @@accounts
  end
  def self.qos_avail
    @@qos_avail
  end
end

DynamicOptions.options

Rails.application.config.after_initialize do
  OodFilesApp.candidate_favorite_paths.tap do |paths|

    # Hash of base paths to check for additional directories with titles
    # location => Title
    base_paths = ['/work/','/scratch/']

    base_paths.each do |base_path|
      # Check if the base path exists and is a directory, to avoid error
      next unless Dir.exist?(base_path)
      if File.readable?(base_path) && File.executable?(base_path)
          paths << FavoritePath.new(base_path)
      end
    end

  end
end
