require 'hashie'
require "logger"
require "pp"
require "json"
require 'aliyun'

module Ecsex
  class Core

    def initialize
      options = {
        :access_key_id => ENV['ALIYUN_ACCESS_KEY_ID'],
        :access_key_secret => ENV['ALIYUN_ACCESS_KEY_SECRET'],
        :service => :ecs
      }
      @ecs = Aliyun::Service.new options
      @region = ENV['ALIYUN_REGION']
      @logger = Logger.new(STDOUT)
    end

    def client
      @ecs
    end

    def logger
      @logger
    end

    def regions
      Hashie::Mash.new(@ecs.DescribeRegions({})).Regions.Region
    end

    def images(parameters)
      options = parameters
      options[:RegionID] = @region
      Hashie::Mash.new(@ecs.DescribeImages options).Images.Image
    end

    def instances(parameters)
      options = parameters
      options[:RegionID] = @region
      Hashie::Mash.new(@ecs.DescribeInstances(options)).Instances.Instance
    end

    def instances_with_id(instance_id)
      options = {}
      options[:InstanceIds] = [instance_id].to_json
      options[:RegionID] = @region
      instances = @ecs.DescribeInstances(options)
      Hashie::Mash.new(instances).Instances.Instance
    end

    def snapshots(parameters)
      options = parameters
      options[:RegionID] = @region
      options[:PageSize] = 100
      Hashie::Mash.new(@ecs.DescribeSnapshots(options)).Snapshots.Snapshot
    end

    def disks(parameters)
      options = parameters
      options[:RegionID] = @region
      Hashie::Mash.new(@ecs.DescribeDisks(options)).Disks.Disk
    end

    def eip_addresses(parameters)
      options = parameters
      options[:RegionID] = @region
      Hashie::Mash.new(@ecs.DescribeEipAddresses(options)).EipAddresses.EipAddress
    end

    def copy_image(parameters)
      options = parameters
      options[:RegionID] = @region
      @ecs.CopyImage(options)
    end

    def create_image_with_instance(instance)
      image_name = %Q{#{instance.InstanceName}.#{Time.now.strftime('%Y%m%d%H%M%S')}}
      description = {}
      description[:pia] = instance.VpcAttributes.PrivateIpAddress.IpAddress.first
      description[:eia] = instance.EipAddress.AllocationId
      description[:d] = instance.Description
      description[:in] = instance.InstanceName
      description[:zid] = instance.ZoneId
      description[:it] = instance.InstanceType
      description[:vsid] = instance.VpcAttributes.VSwitchId
      if instance.SecurityGroupIds.SecurityGroupId.first
        description[:sgid] = instance.SecurityGroupIds.SecurityGroupId.first
      end
      compressed = description.to_json
      parameters = {
        InstanceId: instance.InstanceId,
        ImageName: image_name,
        Description: description.to_json
      }
      create_image(parameters)
    end

    def create_image(parameters)
      options = parameters
      options[:RegionID] = @region
      @ecs.CreateImage(options)
      @logger.info(%Q{creating image => #{parameters[:ImageName]}})
      loop do
        results = images({ImageName: parameters[:ImageName]})
        if !results.empty?
          @logger.info(%Q{ImageId => #{results.first['ImageId']}})
          return results.first
        end
        sleep 10
      end
    end

    def delete_image(parameters)
      @logger.info(%Q{delete image #{parameters}})
      options = parameters
      options[:RegionID] = @region
      @ecs.DeleteImage(options)
    end

    def delete_snapshot(parameters)
      @logger.info(%Q{delete snapshot => #{parameters}})
      options = parameters
      options[:RegionID] = @region
      @ecs.DeleteSnapshot(options)
    end

    def delete_disk(parameters)
      @logger.info(%Q{delete disk => #{parameters}})
      options = parameters
      options[:RegionID] = @region
      @ecs.DeleteDisk(options)
    end

    def create_instance(parameters)
      options = parameters
      options[:RegionID] = @region
      instance = @ecs.CreateInstance(options)
      loop do
        results = instances({instance_name: options[:InstanceName]})
        if results.first.Status == 'Stopped'
          @logger.info(%Q{created #{options[:InstanceName]}})
          return instance
        end
        sleep 10
      end
    end

    def stop_and_delete_instance(instance_id:)
      wait_for_stop(InstanceId: instance_id)
      options = { InstanceId: instance_id }
      @ecs.DeleteInstance(options)
    end

    def delete_instance(parameters)
      @ecs.DeleteInstance(parameters)
      @logger.info(%Q{deleted #{parameters}})
    end

    def delete_instance_with_name(name)
      instances(InstanceName: name).each do |instance|
        parameters = { InstanceId: instance.InstanceId }
        stop_instance(parameters)
        delete_instance(parameters)
      end
    end

    def delete_instance_with_id(instance_id)
      parameters = { InstanceId: instance_id }
      stop_instance(parameters)
      delete_instance(parameters)
    end

    def stop_instance(parameters)
      wait_for_stop(parameters)
    end

    def allocate_eip_address
      options = {}
      options[:RegionID] = @region
      @ecs.AllocateEipAddress(options)
    end

    def release_eip_address(parameters)
      options = parameters
      options[:RegionID] = @region
      @ecs.ReleaseEipAddress(options)
    end

    def associate_eip_address(parameters, define_allocation_id)
      allocation_id = if define_allocation_id
        define_allocation_id
      else
        eip_address = allocate_eip_address
        @logger.info(%Q{allocate #{eip_address}})
        eip_address['AllocationId']
      end
      parameters[:AllocationID] = allocation_id
      parameters[:RegionID] = @region
      @ecs.AssociateEipAddress(parameters)
    end

    def unassociate_eip_address(parameters)
      parameters[:RegionID] = @region
      @ecs.UnassociateEipAddress(parameters)
    end

    def start_instance(parameters)
      parameters[:RegionID] = @region
      @ecs.StartInstance(parameters)
    end

    def wait_for_stop(parameters)
      results = instances_with_id(parameters[:InstanceId])
      return if results.first.Status == 'Stopped'
      @ecs.StopInstance(parameters)
      loop do
        results = instances_with_id(parameters[:InstanceId])
        if results.first.Status == 'Stopped'
          @logger.info(%Q{stopped #{parameters[:InstanceId]}})
          return
        end
        sleep 10
      end
    end

    def get_data_disk_with_image(image)
      parameters = {}
      disks = image.DiskDeviceMappings.DiskDeviceMapping
      if disks.size > 1
        disks.shift
        disks.each_with_index do |disk, i|
          parameters[:"DataDisk.#{i + 1}.Category"] = 'cloud_efficiency'
          parameters[:"DataDisk.#{i + 1}.SnapshotId"] = disk.SnapshotId
          parameters[:"DataDisk.#{i + 1}.Size"] = disk.Size
          parameters[:"DataDisk.#{i + 1}.Device"] = disk.Device
          parameters[:"DataDisk.#{i + 1}.DeleteWithInstance"] = false
        end
      end
      symbolize_keys(parameters)
    end

    def symbolize_keys(hash)
      hash.each_with_object({}){|(k,v),memo| memo[k.to_s.to_sym]=v}
    end
  end
end
