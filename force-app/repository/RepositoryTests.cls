@IsTest
private class RepositoryTests {
  @IsTest
  static void it_should_take_in_a_query() {
    Query basicQuery = Query.equals(ContactPointAddress.PreferenceRank, 1);
    IRepository repo = new ContactPointAddressRepo();

    repo.get(basicQuery);
    System.assertEquals(1, Limits.getQueries());
  }

  @IsTest
  static void it_should_handle_lists_and_sets_of_ids_or_strings() {
    Id accountId = TestingUtils.generateId(Account.SObjectType);
    Id secondAccountId = TestingUtils.generateId(Account.SObjectType);
    List<Id> ids = new List<Id>{ accountId, secondAccountId };
    Set<Id> setIds = new Set<Id>(ids);
    Set<String> cpaNames = new Set<String>{ 'Open', 'Closed' };

    Query listQuery = Query.equals(ContactPointAddress.ParentId, ids);
    Query setQuery = Query.equals(ContactPointAddress.ParentId, setIds);
    Query setStringQuery = Query.equals(ContactPointAddress.Name, cpaNames);

    IRepository repo = new ContactPointAddressRepo();

    repo.get(listQuery);
    repo.get(setQuery);
    repo.get(setStringQuery);
    System.assertEquals(3, Limits.getQueries());
    System.assertEquals('Name = :bindVar3', setStringQuery.toString());
    System.assertEquals(cpaNames, setStringQuery.getBindVars().get('bindVar3'));
  }

  @IsTest
  static void it_should_query_with_empty_collections() {
    Query listQuery = Query.equals(ContactPointAddress.Id, new List<Id>());

    IRepository repo = new ContactPointAddressRepo();

    List<SObject> opps = repo.get(listQuery);
    System.assertEquals(0, opps.size());
    System.assertEquals(1, Limits.getQueries());
  }

  @IsTest
  static void it_should_respect_or_statements_in_queries() {
    ContactPointAddress cpa = new ContactPointAddress(Name = 'Test Or', PreferenceRank = 1);
    ContactPointAddress secondCpa = new ContactPointAddress(Name = 'Test Or Two', PreferenceRank = 2);
    insert new List<ContactPointAddress>{ cpa, secondCpa };

    IRepository repo = new ContactPointAddressRepo();

    Id nullId = null;
    Query andQuery = Query.equals(ContactPointAddress.ParentId, nullId);
    Query orQuery = Query.orQuery(
      Query.equals(ContactPointAddress.PreferenceRank, cpa.PreferenceRank),
      Query.equals(ContactPointAddress.PreferenceRank, secondCpa.PreferenceRank)
    );

    List<ContactPointAddress> cpas = repo.get(new List<Query>{ andQuery, orQuery });
    System.assertEquals(2, cpas.size());
  }

  @IsTest
  static void it_should_respect_not_like_syntax_for_multiple_values() {
    ContactPointAddress cpa = new ContactPointAddress(Name = 'Test Or', PreferenceRank = 1);
    ContactPointAddress secondCpa = new ContactPointAddress(Name = 'Something different', PreferenceRank = 2);
    insert new List<ContactPointAddress>{ cpa, secondCpa };

    IRepository repo = new ContactPointAddressRepo();

    Query notLike = Query.notLike(ContactPointAddress.Name, new List<String>{ cpa.Name, 'someOtherString' });

    List<ContactPointAddress> cpas = repo.get(notLike);

    System.assertEquals(1, cpas.size());
    System.assertEquals(secondCpa.Id, cpas[0].Id);
  }

  @IsTest
  static void it_should_add_parent_fields() {
    GroupMemberRepo repo = new GroupMemberRepo();
    repo.addParentFields(
      new List<Schema.SObjectField>{ GroupMember.GroupId },
      new List<Schema.SObjectField>{ Group.Id }
    );

    Group grp = new Group(Name = 'Group');
    insert grp;
    GroupMember member = new GroupMember(GroupId = grp.Id, UserOrGroupId = UserInfo.getUserId());
    insert member;
    List<GroupMember> members = repo.getAll();

    System.assertEquals(1, members.size());
    System.assertEquals(grp.Id, members[0].Group.Id);
  }

  @IsTest
  static void it_should_add_child_fields() {
    IRepository repo = new AccountRepo();
    repo.addChildFields(Contact.AccountId, new List<Schema.SObjectField>{ Contact.AccountId, Contact.LastName });

    Account acc = new Account(Name = 'Parent');
    insert acc;
    Contact con = new Contact(AccountId = acc.Id, LastName = 'Child');
    insert con;

    List<Account> accounts = repo.getAll();

    System.assertEquals(1, accounts.size());
    System.assertEquals(1, accounts.get(0).Contacts.size());
    Contact returnedCon = accounts.get(0).Contacts.get(0);
    System.assertEquals(con, returnedCon);
  }

  @IsTest
  static void it_should_decorate_dml_methods() {
    IRepository repo = Factory.getFactory().withMocks.RepoFactory.getOppRepo();
    Account acc = new Account();
    List<Account> accs = new List<Account>{ acc };

    repo.doInsert(acc);
    repo.doInsert(accs);
    System.assertEquals(acc, DMLMock.Inserted.Accounts.firstOrDefault);

    repo.doUpdate(acc);
    repo.doUpdate(accs);
    System.assertEquals(acc, DMLMock.Updated.Accounts.firstOrDefault);

    repo.doUpsert(acc);
    repo.doUpsert(accs);
    System.assertEquals(acc, DMLMock.Upserted.Accounts.firstOrDefault);

    repo.doDelete(acc);
    repo.doDelete(accs);
    System.assertEquals(acc, DMLMock.Deleted.Accounts.firstOrDefault);

    repo.doUndelete(acc);
    repo.doUndelete(accs);
    System.assertEquals(acc, DMLMock.Undeleted.Accounts.firstOrDefault);

    repo.doHardDelete(acc);
    repo.doHardDelete(accs);
    System.assertEquals(acc, DMLMock.Deleted.Accounts.firstOrDefault);
  }

  private class GroupMemberRepo extends Repository {
    public GroupMemberRepo() {
      super(GroupMember.SObjectType, new List<Schema.SObjectField>{ GroupMember.GroupId }, new RepoFactoryMock());
    }
  }

  private class ContactPointAddressRepo extends Repository {
    public ContactPointAddressRepo() {
      super(
        ContactPointAddress.SObjectType,
        new List<Schema.SObjectField>{
          ContactPointAddress.Id,
          ContactPointAddress.PreferenceRank,
          ContactPointAddress.ParentId,
          ContactPointAddress.Name
        },
        new RepoFactoryMock()
      );
    }
  }

  private class AccountRepo extends Repository {
    public AccountRepo() {
      super(Account.SObjectType, new List<Schema.SObjectField>(), new RepoFactoryMock());
    }
  }
}
