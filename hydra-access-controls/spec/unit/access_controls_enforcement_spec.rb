require 'spec_helper'

describe Hydra::AccessControlsEnforcement do
  before(:all) do
    class MockController
      include Hydra::AccessControlsEnforcement
      attr_accessor :params
      
      def current_ability
        @current_ability ||= Ability.new(current_user)
      end

      def session
      end
    end
  end
  subject { MockController.new }
  
  describe "When I am searching for content" do
    before do
      @solr_parameters = {}
      @user_parameters = {}
    end
    context "Given I am not logged in" do
      before do
        subject.stub(:current_user).and_return(User.new(:new_record=>true))
        subject.send(:apply_gated_discovery, @solr_parameters, @user_parameters)
      end
      it "Then I should be treated as a member of the 'public' group" do
        ["discover","edit","read"].each do |type|
          @solr_parameters[:fq].first.should match(/#{type}_access_group_ssim\:public/)      
        end
      end
      it "Then I should not be treated as a member of the 'registered' group" do
        @solr_parameters[:fq].first.should_not match(/registered/) 
      end
      it "Then I should not have individual or group permissions"
      it "Should changed based on the discovery_perissions" do
        @solr_parameters = {}
        discovery_permissions = ["read","edit"]
        subject.send(:apply_gated_discovery, @solr_parameters, @user_parameters)
        ["edit","read"].each do |type|
          @solr_parameters[:fq].first.should match(/#{type}_access_group_ssim\:public/)      
        end
      end
    end
    context "Given I am a registered user" do
      before do
        @user = FactoryGirl.build(:martia_morocco)
        @user.new_record = false
        User.stub(:find_by_user_key).and_return(@user)
        # This is a pretty fragile way to stub it...
        RoleMapper.stub(:byname).and_return(@user.user_key=>["faculty", "africana-faculty"])
        subject.stub(:current_user).and_return(@user)
        subject.send(:apply_gated_discovery, @solr_parameters, @user_parameters)
      end
      it "Then I should be treated as a member of the 'public' and 'registered' groups" do
        ["discover","edit","read"].each do |type|
          @solr_parameters[:fq].first.should match(/#{type}_access_group_ssim\:public/)  
          @solr_parameters[:fq].first.should match(/#{type}_access_group_ssim\:registered/)      
        end
      end
      it "Then I should see assets that I have discover, read, or edit access to" do
        ["discover","edit","read"].each do |type|
          @solr_parameters[:fq].first.should match(/#{type}_access_person_ssim\:#{@user.user_key}/)      
        end
      end
      it "Then I should see assets that my groups have discover, read, or edit access to" do
        ["faculty", "africana-faculty"].each do |group_id|
          ["discover","edit","read"].each do |type|
            @solr_parameters[:fq].first.should match(/#{type}_access_group_ssim\:#{group_id}/)      
          end
        end
      end
      it "Should changed based on the discovery_perissions" do
        @solr_parameters = {}
        discovery_permissions = ["read","edit"]
        subject.send(:apply_gated_discovery, @solr_parameters, @user_parameters)
        ["faculty", "africana-faculty"].each do |group_id|
          ["edit","read"].each do |type|
            @solr_parameters[:fq].first.should match(/#{type}_access_group_ssim\:#{group_id}/)      
          end
        end
      end
    end
  end
  
  describe "enforce_show_permissions" do
    it "should allow a user w/ edit permissions to view an embargoed object" do
      user = User.new :uid=>'testuser@example.com'
      RoleMapper.stub(:roles).with(user).and_return(["archivist"])
      subject.stub(:current_user).and_return(user)
      subject.stub(:can?).with(:read, nil).and_return(true)
      stub_doc = Hydra::PermissionsSolrDocument.new({"edit_access_person_ssim"=>["testuser@example.com"], "embargo_release_date_dtsi"=>(Date.parse(Time.now.to_s)+2).to_s})

      subject.params = {}
      subject.should_receive(:can?).with(:edit, stub_doc).and_return(true)
      subject.current_ability.should_receive(:get_permissions_solr_response_for_doc_id).and_return(stub_doc)
      lambda {subject.send(:enforce_show_permissions, {}) }.should_not raise_error Hydra::AccessDenied
    end
    it "should prevent a user w/o edit permissions from viewing an embargoed object" do
      user = User.new :uid=>'testuser@example.com'
      RoleMapper.stub(:roles).with(user).and_return([])
      subject.stub(:current_user).and_return(user)
      subject.stub(:can?).with(:read, nil).and_return(true)
      subject.params = {}
      stub_doc = Hydra::PermissionsSolrDocument.new({"edit_access_person_ssim"=>["testuser@example.com"], "embargo_release_date_dtsi"=>(Date.parse(Time.now.to_s)+2).to_s})
      subject.current_ability.should_receive(:get_permissions_solr_response_for_doc_id).and_return(stub_doc)
      subject.should_receive(:can?).with(:edit, stub_doc).and_return(false)
      lambda {subject.send(:enforce_show_permissions, {})}.should raise_error Hydra::AccessDenied, "This item is under embargo.  You do not have sufficient access privileges to read this document."
    end
  end
  describe "apply_gated_discovery" do
    before(:each) do
      @stub_user = User.new :uid=>'archivist1@example.com'
      RoleMapper.stub(:roles).with(@stub_user).and_return(["archivist","researcher"])
      subject.stub(:current_user).and_return(@stub_user)
      @solr_parameters = {}
      @user_parameters = {}
    end
    it "should set query fields for the user id checking against the discover, access, read fields" do
      subject.send(:apply_gated_discovery, @solr_parameters, @user_parameters)
      ["discover","edit","read"].each do |type|
        @solr_parameters[:fq].first.should match(/#{type}_access_person_ssim\:#{@stub_user.user_key}/)      
      end
    end
    it "should set query fields for all roles the user is a member of checking against the discover, access, read fields" do
      subject.send(:apply_gated_discovery, @solr_parameters, @user_parameters)
      ["discover","edit","read"].each do |type|
        @solr_parameters[:fq].first.should match(/#{type}_access_group_ssim\:archivist/)        
        @solr_parameters[:fq].first.should match(/#{type}_access_group_ssim\:researcher/)        
      end
    end

    it "should escape slashes in the group names" do
      RoleMapper.stub(:roles).with(@stub_user).and_return(["abc/123","cde/567"])
      subject.send(:apply_gated_discovery, @solr_parameters, @user_parameters)
      ["discover","edit","read"].each do |type|
        @solr_parameters[:fq].first.should match(/#{type}_access_group_ssim\:abc\\\/123/)        
        @solr_parameters[:fq].first.should match(/#{type}_access_group_ssim\:cde\\\/567/)        
      end
    end
    it "should escape spaces in the group names" do
      RoleMapper.stub(:roles).with(@stub_user).and_return(["abc 123","cd/e 567"])
      subject.send(:apply_gated_discovery, @solr_parameters, @user_parameters)
      ["discover","edit","read"].each do |type|
        @solr_parameters[:fq].first.should match(/#{type}_access_group_ssim\:abc\\ 123/)
        @solr_parameters[:fq].first.should match(/#{type}_access_group_ssim\:cd\\\/e\\ 567/)
      end
    end
    it "should escape colons in the group names" do
      RoleMapper.stub(:roles).with(@stub_user).and_return(["abc:123","cde:567"])
      subject.send(:apply_gated_discovery, @solr_parameters, @user_parameters)
      ["discover","edit","read"].each do |type|
        @solr_parameters[:fq].first.should match(/#{type}_access_group_ssim\:abc\\:123/)
        @solr_parameters[:fq].first.should match(/#{type}_access_group_ssim\:cde\\:567/)
      end
    end
  end
  
  describe "exclude_unwanted_models" do
    before(:each) do
      stub_user = User.new :uid=>'archivist1@example.com'
      subject.stub(:current_user).and_return(stub_user)
      @solr_parameters = {}
      @user_parameters = {}
    end
    it "should set solr query parameters to filter out FileAssets" do
      subject.send(:exclude_unwanted_models, @solr_parameters, @user_parameters)
      @solr_parameters[:fq].should include("-#{ActiveFedora::SolrService.solr_name("has_model", :symbol)}:\"info:fedora/afmodel:FileAsset\"")  
    end
  end

  describe "apply_individual_permissions" do
    describe "when the user is a guest user (user key nil)" do
      before do
        stub_user = User.new
        subject.stub(:current_user).and_return(stub_user)
      end
      it "should not create filters" do
        subject.send(:apply_individual_permissions, ["edit","discover","read"]).should == []
      end
    end
    describe "when the user is a guest user (user key empty string)" do
      before do
        stub_user = User.new :uid=>''
        subject.stub(:current_user).and_return(stub_user)
      end
      it "should not create filters" do
        subject.send(:apply_individual_permissions, ["edit","discover","read"]).should == []
      end
    end
  end
end


