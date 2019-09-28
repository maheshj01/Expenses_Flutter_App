import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:sqfentity/sqfentity.dart';
import 'package:sqfentity_gen/sqfentity_gen.dart';
part 'model.g.dart';

const expenseTable = SqfEntityTable(
    tableName: 'expense',
    primaryKeyName: 'id',
    primaryKeyType: PrimaryKeyType.integer_auto_incremental,
    useSoftDeleting: true,
    modelName: null,
    fields: [
      SqfEntityField('amount', DbType.real),
      SqfEntityField('description', DbType.text),
      SqfEntityField('total', DbType.real, defaultValue: 1.0)
    ]);

const seqIdentity = SqfEntitySequence(
  sequenceName: 'identity',
  // maxValue:  10000, /* optional. default is max int (9.223.372.036.854.775.807) */
  // modelName: 'SQEidentity',
  /* optional. SqfEntity will set it to sequenceName automatically when the modelName is null*/
  // cycle : false,   /* optional. default is false; */
  // minValue = 0;    /* optional. default is 0 */
  // incrementBy = 1; /* optional. default is 1 */
  // startWith = 0;   /* optional. default is 0 */
);

@SqfEntityBuilder(expenseModel)
const expenseModel = SqfEntityModel(
    modelName: 'expenseModal', // optional
    databaseName: 'expenseORM.db',
    // put defined tables into the tables list.
    databaseTables: [expenseTable],
    // put defined sequences into the sequences list.
    sequences: [seqIdentity],
    bundledDatabasePath:
        null // 'assets/sample.db' // This value is optional. When bundledDatabasePath is empty then EntityBase creats a new database when initializing the database
    );
