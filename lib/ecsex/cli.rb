require "thor"
require 'json_color'

module Ecsex
  class CLI < Thor

    map '-v' => :version

    def initialize(args = [], options = {}, config = {})
      super(args, options, config)
      @global_options = config[:shell].base.options
      @core = Core.new
      @ecs = @core.client
      @logger = @core.logger
    end

    desc 'regions', 'regions'
    def regions
      puts_json @core.regions
    end

    desc 'images', 'images'
    option :name, aliases: '-n', type: :string, required: false, desc: 'name'
    option :size, type: :numeric, desc: 'size'
    def images
      parameters = {
        ImageName: options[:name]
      }
      parameters[:PageSize] = options[:size] if options[:size]
      puts_json @core.images(parameters)
    end

    desc 'deregister_image', 'deregister_image'
    option :name, aliases: '-n', type: :string, required: false, desc: 'name'
    option :older_than, type: :numeric, required: false, default: 2, desc: 'name'
    def deregister_image
      parameters = {
        ImageName: options[:name],
        ImageOwnerAlias: 'self',
        Usage: 'none',
        Status: 'Available',
        PageSize: 100
      }

      results = Hash.new{|h,k| h[k] = []}
      images = @core.images(parameters).sort_by{ |a| Time.parse(a["CreationTime"])}.reverse
      images.each do |image|
        tag = JSON.parse(image.Description, { symbolize_names: true })
        results[tag[:in]] << image
      end
      results.each do |k , one_images|
        one_images.shift(options[:older_than])
        one_images.each do |image|
          @core.delete_image({ ImageID: image.ImageId })
          image.DiskDeviceMappings.DiskDeviceMapping.each do |disk|
            parameters = {
              SnapshotId: disk.SnapshotId,
            }
            @core.delete_snapshot(parameters)
          end
        end
      end
    end

    desc 'instances', 'instances'
    option :name, aliases: '-n', type: :string, desc: 'name'
    option :size, type: :numeric, desc: 'size'
    def instances
      parameters = {
        InstanceName: options[:name]
      }
      parameters[:PageSize] = options[:size] if options[:size]
      puts_json @core.instances(parameters)
    end

    desc 'snapshots', 'snapshots'
    option :name, aliases: '-n', type: :string, required: false, desc: 'name'
    option :size, type: :numeric, desc: 'size'
    def snapshots
      parameters = {
        SnapshotName: options[:name]
      }
      parameters[:PageSize] = options[:size] if options[:size]
      puts_json @core.snapshots(parameters)
    end

    desc 'eip_addresses', 'eip_addresses'
    option :eip_address, aliases: '-e', type: :string, desc: 'eip_address'
    def eip_addresses
      parameters = {}
      parameters[:EipAddress] = options[:eip_address] if options[:eip_address]
      puts_json @core.eip_addresses(parameters)
    end

    desc 'disks', 'disks'
    option :name, aliases: '-n', type: :string, desc: 'name'
    def disks
      parameters = {}
      parameters[:DiskName] = options[:name] if options[:name]
      puts_json @core.disks(parameters)
    end

    desc 'release_eip_addresses', 'release_eip_addresses'
    option :eip_address, aliases: '-e', type: :string, desc: 'eip_address'
    def release_eip_addresses
      parameters = {}
      parameters[:EipAddress] = options[:eip_address] if options[:eip_address]
      @core.eip_addresses(parameters).each do |eip_addresse|
        @core.release_eip_address({ AllocationID: eip_addresse['AllocationId']})
      end
    end

    desc 'unassociate_eip_address', 'unassociate_eip_address'
    option :name, aliases: '-n', type: :string, required: true, desc: 'name'
    def unassociate_eip_address
      @core.instances(InstanceName: options[:name]).each do |instance|
        @core.unassociate_eip_address({ InstanceID: instance.InstanceId, AllocationID: instance.EipAddress.AllocationId })
      end
    end

    desc 'associate_eip_address', 'associate_eip_address'
    option :name, aliases: '-n', type: :string, required: true, desc: 'name'
    option :eip_address, aliases: '-e', type: :string, required: true, desc: 'eip_address'
    def associate_eip_address
      eip_address = @core.eip_addresses({ eip_address: options[:eip_address] }).first
      instance = @core.instances(InstanceName: options[:name]).first
      @core.associate_eip_address({ InstanceID: instance.InstanceId }, eip_address.AllocationId)
    end

    desc 'copy_image', 'copy_image'
    option :name, aliases: '-n', type: :string, required: true, desc: 'name'
    option :destination_region_id, type: :string, required: true, desc: 'destination_region_id'
    def copy_image
      @core.images(ImageName: options[:name]).each do |image|
        parameters = {
          ImageID: image.ImageId,
          DestinationImageName: image.ImageName,
          DestinationDescription: image.Description,
          DestinationRegionID: options[:destination_region_id]
        }
        @core.copy_image(parameters)
      end
    end

    desc 'create_image', 'create_image'
    option :name, aliases: '-n', type: :string, required: true, desc: 'name'
    def create_image
      @core.instances(InstanceName: options[:name]).each do |instance|
        @core.create_image_with_instance(instance)
      end
    end

    desc 'copy', 'copy'
    option :name, aliases: '-n', type: :string, required: true, desc: 'name'
    option :params, aliases: '-p', type: :hash, default: {}, desc: 'params'
    option :renew, aliases: '-r', type: :boolean, default: false, desc: 'renew'
    option :auto_eip_address, type: :boolean, default: false, desc: 'auto_eip_address'
    def copy
      @core.instances(InstanceName: options[:name]).each do |instance|
        image = @core.create_image_with_instance(instance)
        if options[:renew]
          @core.delete_instance_with_id(instance.InstanceId)
        end
        parameters = {
          'SystemDisk.Category': 'cloud_efficiency',
          ImageID: image.ImageId,
          ZoneID: instance.ZoneId,
          InstanceName: instance.InstanceName,
          InstanceType: instance.InstanceType,
          HostName: instance.HostName,
          VSwitchID: instance.VpcAttributes.VSwitchId,
          SecurityGroupID: instance.SecurityGroupIds.SecurityGroupId.first,
          Description: instance.Description,
          PrivateIpAddress: instance.VpcAttributes.PrivateIpAddress.IpAddress.first
        }
        parameters.merge!(@core.get_data_disk_with_image(image))
        parameters.merge!(options[:params].each_with_object({}){|(k,v),memo| memo[k.to_s.to_sym]=v})
        created_instance = @core.create_instance(parameters)
        if options[:auto_eip_address]
          @core.associate_eip_address({InstanceID: created_instance['InstanceId']}, instance.EipAddress.AllocationId)
        end
        @core.start_instance({InstanceID: created_instance['InstanceId']})
      end
    end

    desc 'run_instance', 'run_instance'
    option :name, aliases: '-n', type: :string, required: true, desc: 'name'
    option :params, aliases: '-p', type: :hash, default: {}, desc: 'params'
    option :auto_eip_address, type: :boolean, default: false, desc: 'auto_eip_address'
    def run_instance
      image = @core.images({ ImageName: options[:name] + '.*'}).max_by{ |image| image.CreationTime }
      attributes = Hashie::Mash.new(JSON.parse(image.Description))
      parameters = {
        'SystemDisk.Category': 'cloud_efficiency',
        ImageID: image.ImageId,
        ZoneID: attributes.zid,
        InstanceName: attributes.in,
        InstanceType: attributes.it,
        HostName: attributes.in,
        VSwitchID: attributes.vsid,
        SecurityGroupID: attributes.sgid,
        Description: attributes.d,
        PrivateIpAddress: attributes.pia
      }
      parameters.merge!(@core.get_data_disk_with_image(image))
      parameters.merge!(@core.symbolize_keys(options[:params]))
      created_instance = @core.create_instance(parameters)
      eip_address = @core.eip_addresses({ EipAddress: attributes.eia }).first
      if options[:auto_eip_address] || eip_address
        @core.associate_eip_address({ InstanceID: created_instance['InstanceId']}, eip_address.nil? ? nil : eip_address.AllocationId)
      end
      @core.start_instance({ InstanceID: created_instance['InstanceId']})
    end

    desc 'delete_snapshot', 'delete_snapshot'
    option :name, aliases: '-n', type: :string, required: false, desc: 'name'
    def delete_snapshot
      @core.snapshots(SnapshotName: options[:name], Usage: 'none').each do |snapshot|
        parameters = {
          SnapshotID: snapshot.SnapshotId,
        }
        @core.delete_snapshot(parameters)
      end
    end

    desc 'delete_disk', 'delete_disk'
    option :name, aliases: '-n', type: :string, required: false, desc: 'name'
    def delete_disk
      @core.disks(DiskName: options[:name]).each do |disk|
        parameters = {
          DiskID: disk.DiskId,
        }
        @core.delete_disk(parameters)
      end
    end

    desc 'delete_instance', 'delete_instance'
    option :name, aliases: '-n', type: :string, required: true, desc: 'name'
    def delete_instance
      @core.delete_instance_with_name(options[:name])
    end

    desc 'stop_instance', 'stop_instance'
    option :name, aliases: '-n', type: :string, required: true, desc: 'name'
    def stop_instance
      @core.instances(InstanceName: options[:name]).each do |instance|
        parameters = { InstanceId: instance.InstanceId }
        puts @core.stop_instance(parameters)
      end
    end

    desc 'version', 'show version'
    def version
      puts VERSION
    end

    private

    def puts_json(data)
      puts JsonColor.colorize(JSON.pretty_generate(data))
    end
  end
end
