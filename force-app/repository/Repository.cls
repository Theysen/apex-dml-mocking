public virtual without sharing class Repository implements IRepository {
  private final IDML dml;
  private final List<Schema.SObjectField> queryFields;
  protected final Schema.SObjectType repoType;
  private final Set<String> selectFields;
  private final Map<Schema.SObjectField, String> childToRelationshipNames;
  private final Map<String, Object> bindVars = new Map<String, Object>();

  private System.AccessLevel accessLevel = System.AccessLevel.SYSTEM_MODE;
  private Boolean baseSelectUsed = false;

  public Repository(Schema.SObjectType repoType, List<Schema.SObjectField> queryFields, RepoFactory repoFactory) {
    this(repoFactory);
    this.queryFields = queryFields;
    this.repoType = repoType;
    this.selectFields = new Set<String>();
    this.childToRelationshipNames = this.getChildRelationshipNames(repoType);
  }

  protected Repository(RepoFactory repoFactory) {
    this.dml = repoFactory.getDml();
  }

  // SOQL
  public virtual List<SObject> get(Query query) {
    return this.get(new List<Query>{ query });
  }

  public virtual List<SObject> get(List<Query> queries) {
    String finalQuery = this.getFinalQuery(queries);
    return this.performQuery(finalQuery);
  }

  public virtual List<SObject> getAll() {
    return this.get(new List<Query>());
  }

  public void addParentFields(List<Schema.SObjectField> parentTypes, List<Schema.SObjectField> parentFields) {
    String parentBase = '';
    for (SObjectField parentId : parentTypes) {
      parentBase += parentId.getDescribe().getRelationshipName() + '.';
    }
    for (SObjectField parentField : parentFields) {
      this.selectFields.add(parentBase + parentField.getDescribe().getName());
    }
  }

  public void addChildFields(Schema.SObjectField childFieldToken, List<Schema.SObjectField> childFields) {
    if (this.childToRelationshipNames.containsKey(childFieldToken)) {
      String baseSubselect = '(SELECT {0} FROM {1})';
      Set<String> childFieldNames = new Set<String>{ 'Id' };
      for (SObjectField childField : childFields) {
        childFieldNames.add(childField.getDescribe().getName());
      }
      this.selectFields.add(
        String.format(
          baseSubselect,
          new List<String>{
            String.join(new List<String>(childFieldNames), ','),
            this.childToRelationshipNames.get(childFieldToken)
          }
        )
      );
    }
  }

  public Repository setAccessLevel(System.AccessLevel accessLevel) {
    this.accessLevel = accessLevel;
    return this;
  }

  protected virtual Set<String> addSelectFields() {
    this.baseSelectUsed = true;
    Set<String> fieldStrings = new Set<String>{ 'Id' };
    for (SObjectField field : this.queryFields) {
      fieldStrings.add(field.getDescribe().getName());
    }
    return fieldStrings;
  }

  protected virtual String getFinalQuery(List<Query> queries) {
    return this.getSelectAndFrom() + this.addWheres(queries);
  }

  private Map<Schema.SObjectField, String> getChildRelationshipNames(Schema.SObjectType repoType) {
    Map<Schema.SObjectField, String> localChildToRelationshipNames = new Map<Schema.SObjectField, String>();
    for (Schema.ChildRelationship childRelationship : repoType.getDescribe().getChildRelationships()) {
      localChildToRelationshipNames.put(childRelationship.getField(), childRelationship.getRelationshipName());
    }
    return localChildToRelationshipNames;
  }

  private String getSelectAndFrom() {
    Set<String> localSelectFields = this.addSelectFields();
    if (this.baseSelectUsed) {
      localSelectFields.addAll(this.selectFields);
      this.baseSelectUsed = false;
    }
    return 'SELECT ' + String.join(new List<String>(localSelectFields), ', ') + '\nFROM ' + this.repoType;
  }

  private String addWheres(List<Query> queries) {
    List<String> wheres = new List<String>();
    for (Query qry : queries) {
      wheres.add(qry.toString());
      this.bindVars.putAll(qry.getBindVars());
    }
    return wheres.isEmpty() ? '' : '\nWHERE ' + String.join(wheres, '\nAND ');
  }

  private List<SObject> performQuery(String finalQuery) {
    System.debug('Query: \n' + finalQuery);
    List<SObject> results = Database.queryWithBinds(finalQuery, this.bindVars, this.accessLevel);
    System.debug('Number of results: ' + results.size() + '\nResults: \n' + results);
    return results;
  }

  // DML
  public SObject doInsert(SObject record) {
    return this.dml.doInsert(record);
  }
  public List<SObject> doInsert(List<SObject> records) {
    return this.dml.doInsert(records);
  }

  public SObject doUpdate(SObject record) {
    return this.dml.doUpdate(record);
  }
  public List<SObject> doUpdate(List<SObject> records) {
    return this.dml.doUpdate(records);
  }

  public SObject doUpsert(SObject record) {
    return this.dml.doUpsert(record);
  }
  public List<SObject> doUpsert(List<SObject> records) {
    return this.dml.doUpsert(records);
  }
  public List<SObject> doUpsert(List<SObject> records, Schema.SObjectField field) {
    return this.dml.doUpsert(records, field);
  }

  public SObject doUndelete(SObject record) {
    return this.dml.doUnDelete(record);
  }
  public List<SObject> doUndelete(List<SObject> records) {
    return this.dml.doUndelete(records);
  }

  public void doDelete(SObject record) {
    this.dml.doDelete(record);
  }
  public void doDelete(List<SObject> records) {
    this.dml.doDelete(records);
  }

  public void doHardDelete(SObject record) {
    this.dml.doHardDelete(record);
  }
  public void doHardDelete(List<SObject> records) {
    this.dml.doHardDelete(records);
  }
}
