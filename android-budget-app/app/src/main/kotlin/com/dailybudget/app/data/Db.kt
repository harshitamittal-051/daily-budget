package com.dailybudget.app.data

import android.content.Context
import androidx.room.*
import kotlinx.coroutines.flow.Flow

@Entity(tableName = "txn", indices = [Index(value = ["key"], unique = true), Index("timeMillis")])
data class TxnEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    /** Dedup key: the same SMS arriving live and via a later inbox scan must insert once. */
    val key: String,
    val isDebit: Boolean,
    val amountPaise: Long,
    val merchant: String?,
    val method: String,
    val category: String,
    val timeMillis: Long,
    val isSalary: Boolean,
    val countsTowardBudget: Boolean,
)

data class CategoryTotal(val category: String, val total: Long)
data class MerchantTotal(val merchant: String?, val total: Long, val n: Int)

@Dao
interface TxnDao {
    @Insert(onConflict = OnConflictStrategy.IGNORE)
    suspend fun insert(t: TxnEntity): Long

    @Query("SELECT * FROM txn WHERE timeMillis >= :from ORDER BY timeMillis DESC")
    fun since(from: Long): Flow<List<TxnEntity>>

    @Query("SELECT COALESCE(SUM(amountPaise),0) FROM txn WHERE isDebit=1 AND countsTowardBudget=1 AND timeMillis >= :from AND timeMillis < :to")
    suspend fun spentBetween(from: Long, to: Long): Long

    @Query("SELECT category, SUM(amountPaise) AS total FROM txn WHERE isDebit=1 AND countsTowardBudget=1 AND timeMillis >= :from GROUP BY category ORDER BY total DESC")
    fun byCategory(from: Long): Flow<List<CategoryTotal>>

    @Query("SELECT merchant, SUM(amountPaise) AS total, COUNT(*) AS n FROM txn WHERE isDebit=1 AND countsTowardBudget=1 AND timeMillis >= :from GROUP BY merchant ORDER BY total DESC LIMIT 8")
    fun topMerchants(from: Long): Flow<List<MerchantTotal>>

    @Query("SELECT * FROM txn WHERE isSalary=1 AND timeMillis > :after ORDER BY timeMillis DESC LIMIT 1")
    suspend fun latestSalaryAfter(after: Long): TxnEntity?

    @Query("UPDATE txn SET countsTowardBudget = :counts WHERE id = :id")
    suspend fun setCounts(id: Long, counts: Boolean)

    @Query("UPDATE txn SET category = :cat WHERE id = :id")
    suspend fun setCategory(id: Long, cat: String)
}

@Database(entities = [TxnEntity::class], version = 1, exportSchema = false)
abstract class AppDb : RoomDatabase() {
    abstract fun txns(): TxnDao
    companion object {
        @Volatile private var inst: AppDb? = null
        fun get(c: Context): AppDb = inst ?: synchronized(this) {
            inst ?: Room.databaseBuilder(c.applicationContext, AppDb::class.java, "budget.db").build().also { inst = it }
        }
    }
}
