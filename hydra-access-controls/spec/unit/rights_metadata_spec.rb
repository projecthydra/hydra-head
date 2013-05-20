require 'spec_helper'

describe Hydra::ModelMixins::RightsMetadata do
  subject { ModsAsset.new }
  it "should have a set of permissions" do
    subject.discover_groups=['group1', 'group2']
    subject.edit_users=['user1']
    subject.read_users=['user2', 'user3']
    subject.permissions.should include({:type=>"group", :access=>"discover", :name=>"group1"},
        {:type=>"group", :access=>"discover", :name=>"group2"},
        {:type=>"user", :access=>"read", :name=>"user2"},
        {:type=>"user", :access=>"read", :name=>"user3"},
        {:type=>"user", :access=>"edit", :name=>"user1"})
  end

  describe "updating permissions" do
    it "should create new group permissions" do
      subject.permissions = [{:name=>'group1', :access=>'discover', :type=>'group'}]
      subject.permissions.should == [{:type=>'group', :access=>'discover', :name=>'group1'}]
    end
    it "should create new user permissions" do
      subject.permissions = [{:name=>'user1', :access=>'discover', :type=>'user'}]
      subject.permissions.should == [{:type=>'user', :access=>'discover', :name=>'user1'}]
    end
    it "should not replace existing groups" do
      subject.permissions = [{:name=>'group1', :access=>'discover', :type=>'group'}]
      subject.permissions = [{:name=>'group2', :access=>'discover', :type=>'group'}]
      subject.permissions.should == [{:type=>'group', :access=>'discover', :name=>'group1'},
                                   {:type=>'group', :access=>'discover', :name=>'group2'}]
    end
    it "should not replace existing users" do
      subject.permissions = [{:name=>'user1', :access=>'discover', :type=>'user'}]
      subject.permissions = [{:name=>'user2', :access=>'discover', :type=>'user'}]
      subject.permissions.should == [{:type=>'user', :access=>'discover', :name=>'user1'},
                                   {:type=>'user', :access=>'discover', :name=>'user2'}]
    end
    it "should update permissions on existing users" do
      subject.permissions = [{:name=>'user1', :access=>'discover', :type=>'user'}]
      subject.permissions = [{:name=>'user1', :access=>'edit', :type=>'user'}]
      subject.permissions.should == [{:type=>'user', :access=>'edit', :name=>'user1'}]
    end
    it "should update permissions on existing groups" do
      subject.permissions = [{:name=>'group1', :access=>'discover', :type=>'group'}]
      subject.permissions = [{:name=>'group1', :access=>'edit', :type=>'group'}]
      subject.permissions.should == [{:type=>'group', :access=>'edit', :name=>'group1'}]
    end
    it "should assign user permissions when :type == 'person'" do
      subject.permissions = [{:name=>'user1', :access=>'discover', :type=>'person'}]
      subject.permissions.should == [{:type=>'user', :access=>'discover', :name=>'user1'}]
    end
    it "should raise an ArgumentError when the :type hashkey is invalid" do
      expect{subject.permissions = [{:name=>'user1', :access=>'read', :type=>'foo'}]}.to raise_error(ArgumentError)
    end
  end

  context "to_solr" do
    let(:embargo_release_date) { "2010-12-01" }
    before do
      subject.rightsMetadata.embargo_release_date = embargo_release_date
      subject.rightsMetadata.update_permissions("person"=>{"person1"=>"read","person2"=>"discover"}, "group"=>{'group-6' => 'read', "group-7"=>'read', 'group-8'=>'edit'})
    end
    it "should produce a solr document" do
      result = subject.rightsMetadata.to_solr
      result.size.should == 5
      ## Wrote the test in this way, because the implementation uses a hash, and the hash order is not deterministic (especially in ruby 1.8.7)
      result['read_access_group_ssim'].size.should == 2
      result['read_access_group_ssim'].should include('group-6', 'group-7')
      result['edit_access_group_ssim'].should == ['group-8']
      result['discover_access_person_ssim'].should == ['person2']
      result['read_access_person_ssim'].should == ['person1']
      result['embargo_release_date_dtsi'].should == subject.rightsMetadata.embargo_release_date(:format => :solr_date)
    end
  end

  context "with rightsMetadata" do
    before do
      subject.rightsMetadata.update_permissions("person"=>{"person1"=>"read","person2"=>"discover"}, "group"=>{'group-6' => 'read', "group-7"=>'read', 'group-8'=>'edit'})
    end
    it "should have read groups accessor" do
      subject.read_groups.should == ['group-6', 'group-7']
    end
    it "should have read groups string accessor" do
      subject.read_groups_string.should == 'group-6, group-7'
    end
    it "should have read groups writer" do
      subject.read_groups = ['group-2', 'group-3']
      subject.rightsMetadata.groups.should == {'group-2' => 'read', 'group-3'=>'read', 'group-8' => 'edit'}
      subject.rightsMetadata.individuals.should == {"person1"=>"read","person2"=>"discover"}
    end

    it "should have read groups string writer" do
      subject.read_groups_string = 'umg/up.dlt.staff, group-3'
      subject.rightsMetadata.groups.should == {'umg/up.dlt.staff' => 'read', 'group-3'=>'read', 'group-8' => 'edit'}
      subject.rightsMetadata.individuals.should == {"person1"=>"read","person2"=>"discover"}
    end
    it "should only revoke eligible groups" do
      subject.set_read_groups(['group-2', 'group-3'], ['group-6'])
      # 'group-7' is not eligible to be revoked
      subject.rightsMetadata.groups.should == {'group-2' => 'read', 'group-3'=>'read', 'group-7' => 'read', 'group-8' => 'edit'}
      subject.rightsMetadata.individuals.should == {"person1"=>"read","person2"=>"discover"}
    end
  end

end
