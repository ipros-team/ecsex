require 'spec_helper'
require 'ecsex'

describe Ecsex::Core do
  before do
    @core = Core.new
  end

  it "core not nil" do
    @core.should_not nil
  end

  it "private method" do
    @core.send(:sample, []).should == []
  end

  after do
  end
end
